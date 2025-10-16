Given that this is local-first flutter (dart) application,
  with both a local postgreSQL database and a remote (copy) database, make a plan for the proper app, local database
  (which will be deployed by the app, as it is an Android or iOS app) and the remote database to properly implment the
  flow of data from user interactions, to stored in the local database, to being queued for remote sync, to sucessful
  (or not) remote sync. Include plans for using Open Telemetry to make traces that include local and remote debug
  logging (in addition to the normal Event Sourcing auditable tables).

