# OpenMRS-deidentifier
OpenMRS DB deidentification script based on https://wiki.openmrs.org/pages/viewpage.action?pageId=52625799
* patient_identifier and patient_identifier_type have been truncated
* username/password stored in the DB have been cleared
* person names have been randomized - family and middle name have been removed
* birth dates and months have been randomized (years have been preserved)
* encounter and obs dates have been randomized (sequence of events have been preserved)
* location data has been renamed to something nonsensical
* the usernames have been cleared out, and password reset to admin
* renamed person addresses to something nonsensical
