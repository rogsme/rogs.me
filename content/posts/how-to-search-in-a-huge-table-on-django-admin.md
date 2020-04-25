---
title: "How to search in a  huge table on Django admin"
url: "/2020/02/17/how-to-search-in-a-huge-table-on-django-admin"
date: 2020-02-17T17:08:00-04:00
lastmod: 2020-04-25T12:35:53-03:00
tags : [ "python", "django", "programming" ]
---

<div class="kg-card-markdown">

Hello everyone!

We all know that the Django admin is a super cool tool for Django. You can check your models, and add/edit/delete records from the tables. If you are familiar with Django, I'm sure you already know about it.

I was given a task: Our client wanted to search in a table by one field. It seems easy enough, right? Well, the tricky part is that the table has **523.803.417 records**.

Wow. **523.803.417 records**.

At least the model was not that complex:

On `models.py`:

    class HugeTable(models.Model):
        """Huge table information"""
        search_field = models.CharField(max_length=10, db_index=True, unique=True)
        is_valid = models.BooleanField(default=True)

        def __str__(self):
            return self.search_field

So for Django admin, it should be a breeze, right? **WRONG.**

## The process

First, I just added the search field on the admin.py:

On `admin.py`:

    class HugeTableAdmin(admin.ModelAdmin):
        search_fields = ('search_field', )

    admin.site.register(HugeTable, HugeTableAdmin)

And it worked! I had a functioning search field on my admin.  
![2020-02-14-154646](/2020-02-14-154646.png)

Only one problem: It took **3mins+** to load the page and **5mins+** to search. But at least it was working, right?

## WTF?

First, let's split the issues:

1.  Why was it taking +3mins just to load the page?
2.  Why was it taking +5mins to search if the search field was indexed?

I started tackling the first one, and found it quite easily: Django was getting only 100 records at a time, but **it had to calculate the length for the paginator and the "see more" button on the search bar**  
![2020-02-14-153605](/2020-02-14-153605.png)  
<small>So near, yet so far</small>

## Improving the page load

A quick look at the Django docs told me how to deactivate the "see more" query:

[ModelAdmin.show_full_result_count](https://docs.djangoproject.com/en/2.2/ref/contrib/admin/#django.contrib.admin.ModelAdmin.show_full_result_count)

> Set show_full_result_count to control whether the full count of objects should be displayed on a filtered admin page (e.g. 99 results (103 total)). If this option is set to False, a text like 99 results (Show all) is displayed instead.

On `admin.py`:

    class HugeTableAdmin(admin.ModelAdmin):
        search_fields = ('search_field', )
        show_full_result_count = False

    admin.site.register(HugeTable, HugeTableAdmin)

That fixed one problem, but how about the other? It seemed I needed to do my paginator.

Thankfully, I found an _awesome_ post by Haki Benita called ["Optimizing the Django Admin Paginator"](https://hakibenita.com/optimizing-the-django-admin-paginator) that explained exactly that. Since I didn't need to know the records count, I went with the "Dumb" approach:

On `admin.py`:

    from django.core.paginator import Paginator
    from Django.utils.functional import cached_property

    class DumbPaginator(Paginator):
        """
        Paginator that does not count the rows in the table.
        """
        @cached_property
        def count(self):
            return 9999999999

    class HugeTableAdmin(admin.ModelAdmin):
        search_fields = ('search_field', )
        show_full_result_count = False
        paginator = DumbPaginator

    admin.site.register(HugeTable, HugeTableAdmin)

And it worked! The page was loading blazingly fast :) But the search was still **ultra slow**. So let's fix that.  
![2020-02-14-153840](/2020-02-14-153840.png)

## Improving the search

I checked A LOT of options. I almost went with [Haystack](https://haystacksearch.org/), but it seemed a bit overkill for what I needed. I finally found this super cool tool: [djangoql](https://github.com/ivelum/djangoql/). It allowed me to search the table by using _sql like_ operations, so I could search by `search_field` and make use of the indexation. So I installed it:

On `settings.py`:

    INSTALLED_APPS = [
        ...
        'djangoql',
        ...
    ]

On `admin.py`:

    from django.core.paginator import Paginator
    from django.utils.functional import cached_property
    from djangoql.admin import DjangoQLSearchMixin

    class DumbPaginator(Paginator):
        """
        Paginator that does not count the rows in the table.
        """
        @cached_property
        def count(self):
            return 9999999999

    class HugeTableAdmin(DjangoQLSearchMixin, admin.ModelAdmin):
        show_full_result_count = False
        paginator = DumbPaginator

    admin.site.register(HugeTable, HugeTableAdmin)

And it worked! By performing the query:

    search_field = "my search query"

I get my results in around 1 second.

![2020-02-14-154418](/2020-02-14-154418.png)

## Is it done?

Yes! Now my client can search by `search_field` on a table of 523.803.417 records, very easily and very quickly.

I'm planning to post more Python/Django things I'm learning by working with this client, so you might want to stay tuned :)
