# API Engine

API engine is an API manager written in Perl. it provides a modular programming interface to applications written in Perl. it is based on the ideas of the API system that has evolved throughout the history of juno-ircd and several other IRC-related softwares.

## Design concepts

### Reloading modules

One of the main goals of API engine is to support complete reloading of API modules. Ideally, if a module is loaded and then
immediately unloaded, the symbol tables should be equal to what they were before the module was loaded. Unloading a module
should make it seem as if the module was never loaded. When a module is unloaded, the class containing it is deleted.

### Objective modules

Each module for the API engine must have an instance of API::Module representing the module. This object is used to make changes
that the module must make to provide the functionality it is designed for.

### API::Module Bases

Bases are base classes for API::Module. They provide methods for API modules to use to provide extended functionality. An IRCd,
for example, might have a base that allows modules to register command handlers. It might provide methods such as
`$mod->register_command_handler()`. Bases are loaded as modules require them. API engine comes with no bases. Bases are the
primary way that software customizes API engine's functionality. Without bases, API engine is rather worthless.

# API public methods

API engine supplies multiple methods to manage API engine objects.

## API->new(%options)

Creates a new API engine manager. A program only typically needs a single API engine to manage all of its module.

```perl
my $api = API->new(
    log_sub  => sub { print shift(), "\n" },
    mod_dir  => 'mod',
    base_dir => 'lib/API/Base'
);
```

### Parameters

* __options:__ a hash of constructor options.

### %options - constructor options

* __log_sub:__ *optional*, a code reference to be called when API engine logs something.
* __mod_dir:__ the relative or absolute directory where API modules are stored.
* __base_dir:__ the relative or absolute directory where API::Module bases are stored.

## $api->load_module($module_name)

Attempts to load a module with the specified name.  
Returns 1 on success and `undef` on fail.

```perl
$api->load_module('MyModule');
$api->load_module('Other::Module');
```

### Parameters

* __module_name:__ the name of the module to be loaded.

## $api->unload_module($module_name)

Attempts to unload the module with the specified name.  
Returns 1 on success and `undef` on fail.

```perl
$api->unload_module('MyModule');
$api->unload_module('Other::Module');
```

### Parameters

* __module_name:__ the name of the module to be unloaded.

# API private methods

These methods are provided by the API package, but they are typically only used internally. Use them at your own risk.

## $api->load_base($base_name)

Attempts to load the supplied base if it is not loaded already.  
Returns 1 if the base is already loaded or was loaded successfully; `undef` otherwise.

```perl
$api->load_base('ServerCommands');
```

### Parameters

* __base_name:__ the name of the base to be loaded.

## $api->load_requirements($module)

Attempts to load all of the bases the supplied module requires if they are not already loaded.  
Returns 1 when all of the bases are successfully loaded; `undef` otherwise.

```perl
$api->load_requirements($module) or die 'Could not satisfy module dependencies.';
```

### Parameters

* __module:__ the API::Module object.

## $api->call_unloads($module)

Calls `->unload($module)` on each of the loaded API::Module bases. Allows bases to undo any actions that may have been
done while the module was loaded.

```perl
$api->call_unloads($module);
```

### Parameters

* __module:__ the API::Module object.

## API::class_unload($package_name)

Unloads a Perl package and all of its symbols, almost as if the class never existed.

```perl
API::class_unload('API::Module::SomeModule');
```

### Parameters

* __package_name:__ the name of the package being unloaded.

## $api->log2($message)

Calls the `log_sub` specified in the initializer for logging.

```perl
$api->log2('Hello World!');
```

### Parameters

* __message:__ the message to be logged.

# API::Module methods

These methods of API::Module are used to manage modules.
