# Backend setup

The Rails 8 API requires Ruby 3.4.5, Bundler, and PostgreSQL. From this directory:

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server -p 3000
```

The health endpoint is `http://localhost:3000/up`. The API is served under `/api/v1`.

Run the backend checks with:

```sh
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```

For the complete local setup—including PostgreSQL, frontend startup, seed behavior, and configuration—see the [repository setup guide](../README.md).
