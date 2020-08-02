+++
title = "How I got a residency appointment thanks to Python, Selenium and Telegram"
author = ["Roger Gonzalez"]
date = 2020-08-02
lastmod = 2020-08-02T18:00:39-03:00
tags = ["python", "selenium", "telegram"]
categories = ["programming"]
draft = false
weight = 2001
+++

Hello everyone!

As some of you might know, I'm a Venezuelan 🇻🇪 living in Montevideo, Uruguay 🇺🇾.
I've been living here for almost a year, but because of the pandemic my
residency appointments have slowed down to a crawl, and in the middle of the
quarantine they added a new appointment system. Before, there were no
appointments, you just had to get there early and wait for the secretary to
review your files and assign someone to attend you. But now, they had
implemented an appointment system that you could do from the comfort of your own
home/office. There was just one issue: **there where never appointments available**.

That was a little stressful. I was developing a small _tick_ by checking the
site multiple times a day, with no luck. But then, I decided I wanted to do a
bot that checks the site for me, that way I could just forget about it and let
the computers do it for me.


## Tech {#tech}


### Selenium {#selenium}

I had some experience with Selenium in the past because I had to run automated
tests on an Android application, but I had never used it for the web. I knew it
supported Firefox and had an extensive API to interact with websites. In the
end, I just had to inspect the HTML and search for the "No appointments
available" error message. If the message wasn't there, I needed a way to be
notified so I can set my appointment as fast as possible.


### Telegram Bot API {#telegram-bot-api}

Telegram was my goto because I have a lot of experience with it. It has a
stupidly easy API that allows for superb bot management. I just needed the bot
to send me a message whenever the "No appointments available" message wasn't
found on the site.


## The plan {#the-plan}

Here comes the juicy part: How is everything going to work together?

I divided the work into four parts:

1.  Inspecting the site
2.  Finding the error message on the site
3.  Sending the message if nothing was found
4.  Deploy the job with a cronjob on my VPS


## Inspecting the site {#inspecting-the-site}

Here is the site I needed to inspect:

-   On the first site, I need to click the bottom button. By inspecting the HTML,
    I found out that its name is `form:botonElegirHora`
    ![](/2020-08-02-171251.png)
-   When the button is clicked, it loads a second page that has an error message
    if no appointments are found. The ID of that message is `form:warnSinCupos`.
    ![](/2020-08-02-162205.png)


## Using Selenium to find the error message {#using-selenium-to-find-the-error-message}

First, I needed to define the browser session and its settings. I wanted to run
it in headless mode so no X session is needed:

```python
from selenium import webdriver
from selenium.webdriver.firefox.options import Options

options = Options()
options.headless = True
d = webdriver.Firefox(options=options)
```

Then, I opened the site, looked for the button (`form:botonElegirHora`) and
clicked it

```python
# This is the website I wanted to scrape
d.get('https://sae.mec.gub.uy/sae/agendarReserva/Paso1.xhtml?e=9&a=7&r=13')
elem = d.find_element_by_name('form:botonElegirHora')
elem.click()
```

And on the new page, I looked for the error message (`form:warnSinCupos`)

```python
try:
    warning_message = d.find_element_by_id('form:warnSinCupos')
except Exception:
    pass
```

This was working exactly how I wanted: It opened a new browser session, opened
the site, clicked the button, and then looked for the message. For now, if the
message wasn't found, it does nothing. Now, the script needs to send me a
message if the warning message wasn't found on the page.


## Using Telegram to send a message if the warning message wasn't found {#using-telegram-to-send-a-message-if-the-warning-message-wasn-t-found}

The Telegram bot API has a very simple way to send messages. If you want to read
more about their API, you can check it [here](https://core.telegram.org/).

There are a few steps you need to follow to get a Telegram bot:

1.  First, you need to "talk" to the [Botfather](https://core.telegram.org/bots#6-botfather) to create the bot.
2.  Then, you need to find your Telegram Chat ID. There are a few bots that can help
    you with that, I personally use `@get_id_bot`.
3.  Once you have the ID, you should read the `sendMessage` API, since that's the
    only one we need now. You can check it [here](https://core.telegram.org/bots/api#sendmessage).

So, by using the Telegram documentation, I came up with the following code:

```python
import requests

chat_id = # Insert your chat ID here
telegram_bot_id = # Insert your Telegram bot ID here
telegram_data = {
    "chat_id": chat_id
    "parse_mode": "HTML",
    "text": ("<b>Hay citas!</b>\nHay citas en el registro civil, para "
             f"entrar ve a {SAE_URL}")
}
requests.post('https://api.telegram.org/bot{telegram_bot_id}/sendmessage', data=telegram_data)
```


## The complete script {#the-complete-script}

I added a few loggers and environment variables and voilá! Here is the complete code:

```python
#!/usr/bin/env python3

import os
import requests
from datetime import datetime

from selenium import webdriver
from selenium.webdriver.firefox.options import Options

from dotenv import load_dotenv

load_dotenv() # This loads the environmental variables from the .env file in the root folder

TELEGRAM_BOT_ID = os.environ.get('TELEGRAM_BOT_ID')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID')
SAE_URL = 'https://sae.mec.gub.uy/sae/agendarReserva/Paso1.xhtml?e=9&a=7&r=13'

options = Options()
options.headless = True
d = webdriver.Firefox(options=options)
d.get(SAE_URL)
print(f'Headless Firefox Initialized {datetime.now()}')
elem = d.find_element_by_name('form:botonElegirHora')
elem.click()
try:
    warning_message = d.find_element_by_id('form:warnSinCupos')
    print('No dates yet')
    print('------------------------------')
except Exception:
    telegram_data = {
        "chat_id": TELEGRAM_CHAT_ID,
        "parse_mode": "HTML",
        "text": ("<b>Hay citas!</b>\nHay citas en el registro civil, para "
                 f"entrar ve a {SAE_URL}")
    }
    requests.post('https://api.telegram.org/bot'
                  f'{TELEGRAM_BOT_ID}/sendmessage', data=telegram_data)
    print('Dates found!')
d.close() # To close the browser connection
```

Only one more thing to do, to deploy everything to my VPS


## Deploy and testing on the VPS {#deploy-and-testing-on-the-vps}

This was very easy. I just needed to pull my git repo, install the
`requirements.txt` and set a new cron to run every 10 minutes and check the
site. The cron settings I used where:

```bash
*/10 * * * * /usr/bin/python3 /my/script/location/registro-civil-scraper/app.py >> /my/script/location/registro-civil-scraper/log.txt
```

The `>> /my/script/location/registro-civil-scraper/log.txt` part is to keep the logs on a new file.


## Did it work? {#did-it-work}

Yes! And it worked perfectly. I got a message the following day at 21:00
(weirdly enough, that's 0:00GMT, so maybe they have their servers at GMT time
and it opens new appointments at 0:00).
![](/2020-08-02-170458.png)


## Conclusion {#conclusion}

I always loved to use programming to solve simple problems. With this script, I
didn't need to check the site every couple of hours to get an appointment, and
sincerely, I wasn't going to check past 19:00, so I would've never found it by
my own.

My brother is having similar issues in Argentina, and when I showed him this, he
said one of the funniest phrases I've heard about my profession:

> _"Programmers could take over the world, but they are too lazy"_

I lol'd way too hard at that.

I loved Selenium and how it worked. Recently I created a crawler using Selenium,
Redis, peewee, and Postgres, so stay tuned if you want to know more about that.

In the meantime, if you want to check the complete script, you can see it on my
Git instance: <https://git.rogs.me/me/registro-civil-scraper> or Gitlab, if you
prefer: <https://gitlab.com/rogs/registro-civil-scraper>
