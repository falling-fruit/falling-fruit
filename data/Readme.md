Data processing
================

This folder contains various scripts and functions used for data acquisition and processing.

## Type translation

#### `$ bundle exec rake eol_names`
Fetches common name translations from [EOL.org](http://eol.org/) for each type with a scientific name, and writes the results to `data/eol_names.csv`.

#### `$ bundle exec rake wikipedia_names[language_code]`
Fetches common name translations for the specified language (or all available languages, if not specified) from [Wikipedia.org](http://wikipedia.org/) for each type with a scientific name or wikipedia url defined, and writes the results to `data/wikipedia_names.csv`. The method works most of the time but does make mistakes, since the text formatting in the article is used to infer what is or is not a common name.

#### `join_type_translations.r`
Cleans up and joins together `eol_names.csv` and `wikipedia_names.csv`, then uses the [Gigablast API](http://gigablast.com/api.html) to choose the name most commonly used on the internet alongside the corresponding scientific name. Because errors and inconsistencies are likely, the output should be reviewed and edited manually before importing the translations into the database.

#### `$ bundle exec rake import_type_translations`
Imports type translations into the database. Expects file
`data/<language_code>_names.csv` with fields `ff_id` and `translated_name`.

## Type curation

A suite of [R](https://www.r-project.org/) scripts are used to prepare municipal tree inventories and other large and diverse datasets for import to the Falling Fruit database. The main challenge is matching the common and/or scientific names provided in the dataset to Falling Fruit types.

#### `parsing_template.r`
All datasets are different, but this script is a great starting point.

#### `parsing_functions.r`
Helper functions used by `parsing_template.r`.

#### `species_key.csv`
Large table rating species for humans and bees, updated as needed from this [Google Sheet](https://docs.google.com/spreadsheets/d/1AHujFY3L6AZc3bxIw2Zhjuc7S5Keo6HWUj74MtD-O6E/edit#gid=0) (File > Download as > CSV). 

TODO: Add the contents of this table to the database and replace the table with an api call. Originally only edible species were imported. Now, with the advent of the grafter and pollinator maps, the preferred strategy is to import all species and toggle them within the database.


## Locations import

#### `kml_to_csv.rb`
Converts a KML file to a CSV file with the columns named and ordered as described at [fallingfruit.org/locations/import](https://fallingfruit.org/locations/import).

#### `import_test.csv`
Test csv for locations import, including rows with empty `Type` that should fail import.

#### `import_test_photos.csv`
Same as `import_test.csv`, but with photo urls.


## Miscellaneous

### `map_gather.rb`
Modified from [map-gather](https://github.com/caseypt/map-gather). Retrieves the tabular data and coordinates of an ArcGIS Server point feature layer through the REST API and stores the results locally as a CSV. The field properties are stored as a separate JSON file.

##### Dependencies

- Ruby
- [rest-client](https://github.com/rest-client/rest-client)
- An open ArcGIS Server REST API endpoint to query

##### Usage

`$ ruby map_gather.rb url (outfile = <layer name>) (resultOffset = 0)`

Or, more specifically:

`$ ruby map_gather.rb http://www.example.com/ArcGIS/rest/services/folder_name/map_name/MapServer/layer_index output.csv 0`


#### `geocode.py`
Converts a list of addresses into a list of corresponding lat, lng coordinates

##### Dependencies

- Python

##### Usage

`$ python geocode.py addresses.txt`
