# TODO Centreon dockerization

 - Clean the source tree
 - Should the timezone setting (system and PHP) be done at run time? (in the entrypoint script)

## Entrypoints

### centreondb

 - Properly wait for MariaDB to stop after the initial setup (not just "sleep 4")
