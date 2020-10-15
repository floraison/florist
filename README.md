
# florist

<!--
[![Build Status](https://secure.travis-ci.org/floraison/flor-worklist.svg)](http://travis-ci.org/floraison/flor-worklist)
[![Gem Version](https://badge.fury.io/rb/flor-worklist.svg)](http://badge.fury.io/rb/flor-worklist)
-->

[Flor](https://github.com/floraison/flor) is a "Ruby workflow engine", florist is an extension to flor that adds a few database tables and Ruby classes to manage one or more worklists, where tasks are stored.

It aims to follow the guidance/conventions found at [http://www.workflowpatterns.com/patterns/resource/](http://www.workflowpatterns.com/patterns/resource/).

There is a `WorklistTasker` a flor tasker that, upon receiving a task from the flor engine it's bound to, stores it in its target worklist.

```
                                                          .-----------.
                                                      ,-->| suspended |
   .---------.                                .---------. '-----------'
-->| created |------------------------------->| started |<--'
   '---------'               .--------------. '---------'  .--------.
      |    '---------------->| allocated    |   ^ ^ | '--->| FAILED |
      |  .-----------------. | (single res) |---' | |      '--------'
      |  | offered         | '--------------'     | |   .-----------.
      `->| (1 or more res) |----------------------' `-->| COMPLETED |
         '-----------------'                            '-----------'
```


## API


### Florist::Worklist

A worklist needs access to the a flor engine/unit database and, if it's not the same database, a florist database.

```ruby
list = Florist::Worklist.new(@flor_unit)
list = Florist::Worklist.new('postgresql://127.0.0.1/flor')
list = Florist::Worklist.new(@flor_unit, 'postgresql://127.0.0.1/florist')
list = Florist::Worklist.new('postgresql://127.0.0.1/flor', 'postgresql://127.0.0.1/florist')
# ...
```

Once a worklist is instantiated, one can extract task instances out of it via the `#tasks` accessor. That yields a [Sequel](http://sequel.jeremyevans.net/) dataset.

```ruby
puts "there are currently #{list.tasks.count} task(s) in the worklist"

tasks = list.tasks.all
  # fetches all the tasks in the worklist

tasks = list.tasks.where(domain: 'acme.org.accounting')
  # fetches all the tasks whose domain is exactly 'acme.org.accounting'

tasks = list.tasks.where(Sequel.like(:domain, 'acme.org.accounting.%'))
  # fetches all the tasks under the demain 'acme.org.accounting'
```

TODO continue me


### Florist::Task

```ruby
task = lists.tasks.first

p task.exid    # the id of the execution that emitted the task
p task.tasker  # the tasker name as seen from the execution
p task.name    # the task name

p task.payload
p task.fields   # the hash, the payload of the workitem behind the task
```

#### tasks, transitions, and assignments

As seen above, the task, freshly emitted by a flor engine, starts in the "created" state. The worklist may then automatically assign or offer it to a "resource" (someone or something with access to the worklist).

TODO continue me


### Florist::WorklistTasker

TODO


## LICENSE

MIT, see [LICENSE.txt](LICENSE.txt)

