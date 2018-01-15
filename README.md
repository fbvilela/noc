# Newport Organic Collective

Sends an email with CSV files attached listing orders and a summary for a week. Designed to be used with Sendgrid and Heroku scheduler.

## Usage

```
bundle exec rake email_orders[to_email,from_email,category_id,day_to_run]
```

`to_email`: email to send orders to
`from_email`: email that order sheets will be sent from
`category_id`: category used to select orders
`day_to_run`: rake task is skipped unless the day of the week matches this (used because heroku does not support a weekly schedulers)
