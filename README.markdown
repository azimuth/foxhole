Foxhole
=======

Rails 3.1 heroku hosted app 

Features:
=========

* admin users with full auditing
* add project form
* repeating scheduled velocity data gathering via the basecamp api
* configuration form for project velocity reporting:
    - contract hours
    - rollover hours
* post velocity messages to basecamp project announcement sections
* velocity dashboard - display basic velocity status of all configured projects
    - when within 5% of proper burn rate - green
    - when within 15% of proper burn rate - yellow
    - else - red
  