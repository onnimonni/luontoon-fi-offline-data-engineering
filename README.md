# luontoon.fi offline
Download (luontoon.fi)[https://luontoon.fi] outdoor tracks and amenities data to offline to data engineer your outdoor activities like a proper computer nerd 🤓 📈

> [!CAUTION]
> **⚠️ NOTE:** According to the T&C you can only download the luontoon.fi data for your personal, non-commercial use. See more here: https://www.luontoon.fi/fi/kayttoehdot

This is useful if you want experiment and learn more about `duckdb` or to find local hiking places in Finland.

## Requirements
Check that you have new version of curl and duckdb available:
```
$ brew install duckdb curl

# Ensure that this outputs a date from the last 6 months:
$ curl --version | grep Release
Release-Date: 2025-06-04
```

## Explanation
Luontoon.fi data is stored in mapbox vector tiles (`.pbf`) with zoom levels varying from 4-11.

If the `.pbf` is too big in size it gets corrupted somehow and doesn't work. Because of this certain datasets have to be downloaded on smaller zoom levels.

These can be downloaded with zoom level 4:
* public.restrictedareas_details_view
* public.destinations_view
* public.destinations_details_view
* public.amenities_cluster_summary_view

These on the other hand have to be downloaded with zoom level 8:
* public.restrictedareas_details_view
* public.destinations_view
* public.destinations_details_view
* public.amenities_cluster_summary_view

The files are available in a following structure (`...` means many more files exist but they are hidden):
```
https://luontoon.fi
└── geo
    └── tiles
        ├── public.all_lines_details_view
        │   └── 8
        │       ├── 140
        │       │   ├── 58.pbf
        │       │   └── ...
        │       └── ...
        ├── public.all_lines_view
        │   └── 8
        │       ├── 140
        │       │   ├── 58.pbf
        │       │   └── ...
        │       └── ...
        ├── public.all_lines_view.json
        ├── public.amenities_cluster_summary_view
        │   └── 4
        │       ├── 8
        │       │   ├── 3.pbf
        │       │   └── 4.pbf
        │       └── 9
        │           ├── 3.pbf
        │           └── 4.pbf
        ├── public.amenities_cluster_summary_view.json
        ├── public.amenities_view
        │   └── 8
        │       ├── 140
        │       │   ├── 58.pbf
        │       │   └── ...
        │       └── ...
        ├── public.amenities_view.json
        ├── public.destinations_details_view
        │   └── 4
        │       ├── 8
        │       │   ├── 3.pbf
        │       │   └── 4.pbf
        │       └── 9
        │           ├── 3.pbf
        │           └── 4.pbf
        ├── public.destinations_details_view.json
        ├── public.destinations_view
        │   └── 4
        │       ├── 8
        │       │   ├── 3.pbf
        │       │   └── 4.pbf
        │       └── 9
        │           ├── 3.pbf
        │           └── 4.pbf
        ├── public.destinations_view.json
        ├── public.restrictedareas_details_view
        │   └── 4
        │       ├── 8
        │       │   ├── 3.pbf
        │       │   └── 4.pbf
        │       └── 9
        │           ├── 3.pbf
        │           └── 4.pbf
        └── public.restrictedareas_details_view.json
```

## Query the data online with duckdb
Here's a sample how you can query the data directly from https://luontoon.fi:
```
duckdb -c "LOAD spatial; FROM st_read('https://www.luontoon.fi/geo/tiles/public.all_lines_view/10/595/273.pbf')"
```

## Download all data locally and convert it to compressed geoparquet files

This downloads all paths & amenities from luontoon.fi and converts them to geoparquet files:
```sh
./download.sh
```

After this you will have nice 6 parquet files in `data` directory and all cached `.pbf` vector tiles available locally:

```sh
$ du -sh {data,geo}
 22M	data
379M	geo
```

My recommendation is to delete the `geo` folder afterwise because everything exists in `data` already in much better compressed way.

## Playing with the available data locally
### Seeing the source of the information

I assume `NULL` means Metsähallitus itself:
```sh
$ duckdb -c "SELECT source, COUNT(*) FROM read_parquet('data/*.parquet',union_by_name=True) GROUP BY source"
┌──────────────┬──────────────┐
│    source    │ count_star() │
│   varchar    │    int64     │
├──────────────┼──────────────┤
│ NULL         │         4942 │
│ lipas        │        20827 │
│ uljas        │        14481 │
│ visitfinland │          551 │
└──────────────┴──────────────┘
```

### Querying rental amenities
```sh
duckdb -c "
    SELECT
        source,
        category_name_en,
        description_en,
        is_rental,
        has_overnighting_place,
        accessibility,
        has_campfire_place,
        geom
    FROM 'data/public.amenities_view.parquet'
    WHERE is_rental
"
```

## License
MIT (Code is MIT, Metsähallitus allows using the data solely for personal, non-commerial usage)