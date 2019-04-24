
# flor

<!--
[![Build Status](https://secure.travis-ci.org/floraison/flor-worklist.svg)](http://travis-ci.org/floraison/flor-worklist)
[![Gem Version](https://badge.fury.io/rb/flor-worklist.svg)](http://badge.fury.io/rb/flor-worklist)
-->

[Flor](https://github.com/floraison/flor) is a "Ruby workflow engine", florist is an extension to flor that adds a few database tables and Ruby classes to manage one or more worklists, where tasks are stored.

It aims to follow the guidance/conventions found at [http://www.workflowpatterns.com/patterns/resource/](http://www.workflowpatterns.com/patterns/resource/).

```
                                 .-----------.
                                 | suspended |
                                 '-----------'
                                      ^ |
                                      | |
                                      | v
   .---------.                  .---------.    .-----------.
-->| created |----------------->| started |--->| completed |
   '---------'                  '---------'    '-----------'
         | |                      ^ ^   |
         | |   .--------------.   | |   |   .---------.
         | `-->| allocated    |---' |   `-->| failed  |
         |     | (single res) |     |       '---------'
         |     '--------------'     |
         |        ^                 |
         |        |                 |
         |   .-----------------.    |
         `-->| offered         |----'
             | (1 or more res) |
             '-----------------'
```


## Documentation

See [doc/](doc/).


## LICENSE

MIT, see [LICENSE.txt](LICENSE.txt)

