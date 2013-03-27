DcsPerfA
========

About
-----

DataCore has added a performance recorder into SANsymphony-V version 9.2. It
uses a MSSQL 2012 LocalDB to record configured performance metrics. There
is a build-in trend visualization.

Looking for some more statistical analysis / visualization I've wrote DcsPerfA.
It contains some scripts to fetch the online LocalDB data file (using VSS). You
need an MSSQL 2012 (Express) instance to import the DB files and export them
to a CSV file. The analyze.pl script will convert the CSV and graph the data.

DcsPerfA is *work-in-progress*!


Install
-------

DcsPerfA is a small Perl script and requires the following perl packages:
* Chart::Gnuplot
* Date::Parse


Usage
-----

* export the DB files from the recording Dcs
* import the DB files to your MSSQL instance
* create a new DB and execute tsql/views.sql
* use export/export.cmd to export the recorded data
* call analyze.pl
