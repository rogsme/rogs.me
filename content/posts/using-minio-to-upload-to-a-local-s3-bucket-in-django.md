+++
title = "Using MinIO to upload to a local S3 bucket in Django"
author = ["Roger Gonzalez"]
date = 2021-01-10
lastmod = 2023-01-14T15:04:51-03:00
tags = ["programming", "python", "django", "minio", "docker", "", "dockercompose"]
draft = false
weight = 2001
+++

So MinIO its an object storage that uses the same API as S3, which means that we
can  use the same S3 compatible libraries in Python, like [Boto3](https://pypi.org/project/boto3/) and [django-storages](https://pypi.org/project/django-storages/).


## The setup {#the-setup}

Here's the docker-compose configuration for my django app:

```yaml
version: "3"

services:
  app:
    build:
      context: .
    volumes:
      - ./app:/app
    ports:
      - 8000:8000
    depends_on:
      - minio
    command: >
      sh -c "python manage.py migrate &&
             python manage.py runserver 0.0.0.0:8000"

  minio:
    image: minio/minio
    ports:
      - 9000:9000
    environment:
      - MINIO_ACCESS_KEY=access-key
      - MINIO_SECRET_KEY=secret-key
    command: server /export

  createbuckets:
    image: minio/mc
    depends_on:
      - minio
    entrypoint: >
      /bin/sh -c "
      apk add nc &&
      while ! nc -z minio 9000; do echo 'Wait minio to startup...' && sleep 0.1; done; sleep 5 &&
      /usr/bin/mc config host add myminio http://minio:9000 access-key secret-key;
      /usr/bin/mc mb myminio/my-local-bucket;
      /usr/bin/mc policy download myminio/my-local-bucket;
      exit 0;
      "
```

-   `app` is my Django app. Nothing new here.
-   `minio` is the MinIO instance.
-   `createbuckets` is a quick instance that creates a new bucket on startup, that
    way we don't need to create the bucket manually.

On my app, in `settings.py`:

```python
# S3 configuration

DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"

AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "access-key")
AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "secret-key")
AWS_STORAGE_BUCKET_NAME = os.environ.get("AWS_STORAGE_BUCKET_NAME", "my-local-bucket")

if DEBUG:
    AWS_S3_ENDPOINT_URL = "http://minio:9000"
```

If we were in a production environment, the `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` and `AWS_STORAGE_BUCKET_NAME` would be read from the
environmental variables, but since we haven't set those up and we have
`DEBUG=True`, we are going to use the default ones, which point directly to
MinIO.

And that's it! That's everything you need to have your local S3 development environment.


## Testing {#testing}

First, let's create our model. This is a simple mock model for testing purposes:

```python
from django.db import models


class Person(models.Model):
    """This is a demo person model"""

    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    date_of_birth = models.DateField()
    picture = models.ImageField()

    def __str__(self):
        return f"{self.first_name} {self.last_name} {str(self.date_of_birth)}"
```

Then, in the Django admin we can interact with our new model:

{{< figure src="/2021-01-10-135111.png" >}}

{{< figure src="/2021-01-10-135130.png" >}}

If we go to the URL and change the domain to `localhost`, we should be able to
see the picture we uploaded.

{{< figure src="/2021-01-10-140016.png" >}}


## Bonus: The MinIO browser {#bonus-the-minio-browser}

MinIO has a local objects browser. If you want to check it out you just need to
go to <http://localhost:9000>. With my docker-compose configuration, the
credentials are:

```bash
username: access-key
password: secret-key
```

{{< figure src="/2021-01-10-140236.png" >}}

On the browser, you can see your uploads, delete them, add new ones, etc.

{{< figure src="/2021-01-10-140337.png" >}}


## Conclusion {#conclusion}

Now you can have a simple configuration for your local and production
environments to work seamlessly, using local resources instead of remote
resources that might generate costs for the development.

If you want to check out the project code, you can check in my Gitlab here:
<https://gitlab.com/rogs/minio-example>

See you in the next one!
