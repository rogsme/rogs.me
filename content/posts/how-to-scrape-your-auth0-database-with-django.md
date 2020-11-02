---
title: "How to create a management command and scrape your Auth0 database with Django"
date: 2020-06-30T09:40:48-03:00
lastmod: 2020-06-30T09:40:48-03:00
tags : [ "python", "django", "programming" ]
draft: true
---

Hello everyone! 

Some months ago, our data analyst needed to extract some data from Auth0 and match it with our profiles 
database, so I decided we needed a new table to relate the Auth0 information with the profiles 
information.

# The solution

This was a really easy but interesting task. The steps I came up with were:

- Create a new model to save the data from Auth0
- Create a new management command
- Create a cron to run the management command every night

# Creating the model

The model was really easy, I just created a field for each of the fields I want:

```python
class Auth0Data(models.Model):
    """Auth0 data straight from auth0"""
    profile = models.ForeignKey(Profile, on_delete=models.CASCADE)
    name = models.CharField(max_length=255, blank=True, null=True)
    last_name = models.CharField(max_length=255, blank=True, null=True)
    email = models.CharField(max_length=255, blank=True, null=True)
    last_ip = models.CharField(max_length=255, blank=True, null=True)
    login_count = models.CharField(max_length=255, blank=True, null=True)
    last_login = models.DateTimeField(null=True, blank=True)
    email_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    def __str__(self):
        return str(self.profile)
```

# Creating the management command

I want to run the command with a cron, so I need a way to run it outside of Django's runtime. I want the 
command to run as `python manage.py scrape_auth0`. In order to do this, I have to create a specific 
folder structure inside my application.

Let's asume my Project is called `library` and my Django app is called `book`. I have to create the 
following folder structure:
```
├── library # my project root
│   ├── book # my app name
│   │   ├── management
│   │   │   ├── commands
│   │   │   │   ├── scrape_auth0.py
│   │   │   ├── __init__.py
```

First, let's create the folders we need. On the root of our application we can run:

```sh
mkdir -p book/management/commands
touch book/management/commands/__init__.py
touch book/management/commands/scrape_auth0.py
```

In case you don't know, the `__init__.py` file is used to indentify Pyton packages. 

Now, you can open `scrape_auth0.py` on your text editor and start creating your command!

The basic structure to create a command is:

```python
from django.core.management.base import BaseCommand

class Command(BaseCommand):

    def handle(self, *args, **options):
        # my command here
```

What's going on here?
- First we create the class "Command", and inherit from `BaseCommand`. Every command has to inherit from it
- Inside the class, we need to override the `handle` function. That's where we are going to write our command.

## The complete Auth0 command

Here is the entire command:

```python
import time
import csv
import requests
import gzip
import json
import datetime
import os

from django.core.management.base import BaseCommand
from core.models import Profile, Auth0Data

token = os.environ.get('AUTH0_MANAGEMENT_TOKEN')
headers = {'Authorization': f'Bearer {token}',
           'Content-Type': 'application/json'}


class Command(BaseCommand):
    """Django command to load all the pincodes in the db"""

    def handle(self, *args, **options):
        self.stdout.write('Scraping...')
        self.stdout.write('Getting the connections...')

        connections = requests.get(
            'https://destapp.auth0.com/api/v2/connections',
            headers=headers
        ).json()

        self.stdout.write('Connections found!')

        for connection in connections:
            connection_id = connection['id']
            connection_name = connection['name']
            self.stdout.write(
                f'Working with connection {connection_name}, '
                f'{connection_id}')

            data = json.dumps({
                'connection_id': connection_id,
                'format': 'csv',
                'limit': 99999999,
                'fields': [
                    {
                        'name': 'user_id'
                    },
                    {
                        'name': 'family_name'
                    },
                    {
                        'name': 'given_name'
                    },
                    {
                        'name': 'email'
                    },
                    {
                        'name': 'last_ip'
                    },
                    {
                        'name': 'logins_count'
                    },
                    {
                        'name': 'created_at'
                    },
                    {
                        'name': 'updated_at'
                    },
                    {
                        'name': 'last_login'
                    },
                    {
                        'name': 'email_verified'
                    }
                ]
            })

            self.stdout.write('Generating job...')
            job = requests.post(
                'https://destapp.auth0.com/api/v2/jobs/users-exports',
                data=data,
                headers=headers
            )
            job_id = job.json()['id']
            self.stdout.write(f'The job ID is {job_id}')
            time.sleep(5)

            job_is_running = True

            while job_is_running:
                check_job = requests.get(
                    f'https://destapp.auth0.com/api/v2/jobs/{job_id}',
                    headers=headers
                ).json()

                status = check_job['status']

                if status == 'pending':
                    self.stdout.write('Job has not started, waiting')
                    time.sleep(30)
                elif status == 'processing':
                    percentage_done = check_job['percentage_done']
                    seconds_left = datetime.timedelta(
                        seconds=check_job['time_left_seconds'])

                    self.stdout.write(f'Procesed: {percentage_done}%')
                    self.stdout.write(f'Time left: {seconds_left}')
                    time.sleep(10)
                elif status == 'completed':
                    job_is_running = False
                    self.stdout.write('100%')
                    self.stdout.write('Data is ready!')
                    export_url = check_job['location']

            export_data = requests.get(export_url, stream=True)

            file_location = 'core/management/commands/auth0_file.csv.gz'

            with open(file_location, 'wb') as f:
                self.stdout.write('Downloading the file')
                for chunk in export_data.iter_content(chunk_size=1024):
                    if chunk:
                        f.write(chunk)
                        f.flush()
                self.stdout.write('File ready!')
                f.close()

            with gzip.open(file_location, 'rt') as f:
                reader = csv.reader(f, delimiter=',', quotechar='"')
                for row in reader:
                    auth0_id = row[0].replace('|', '.')
                    last_name = row[1]
                    name = row[2]
                    email = row[3]
                    last_ip = row[4]
                    login_count = row[5]
                    created_at = row[6]
                    updated_at = row[7]
                    last_login = None
                    if row[8] != '':
                        last_login = row[8]
                    email_verified = False
                    if row[9] == 'true':
                        email_verified = True

                    try:
                        profile = Profile.objects.get(auth0_id=auth0_id)
                        auth0_data = Auth0Data.objects.get(profile=profile)

                        auth0_data.name = name
                        auth0_data.last_name = last_name
                        auth0_data.email = email
                        auth0_data.last_ip = last_ip
                        auth0_data.login_count = login_count
                        auth0_data.created_at = created_at
                        auth0_data.updated_at = updated_at
                        auth0_data.last_login = last_login
                        auth0_data.email_verified = email_verified

                        auth0_data.save()
                        self.stdout.write(f'Updated Auth0Data for {profile}')

                    except Auth0Data.DoesNotExist:
                        Auth0Data.objects.create(
                            profile=profile,
                            name=name,
                            last_name=last_name,
                            email=email,
                            last_ip=last_ip,
                            login_count=login_count,
                            created_at=created_at,
                            updated_at=updated_at,
                            last_login=last_login,
                            email_verified=email_verified
                        )
                        self.stdout.write(f'Created Auth0Data for {profile}')
                    except Profile.DoesNotExist:
                        pass
```
