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

### Parameters

* __module_name:__ the name of the module to be loaded.

## $api->unload_module($module_name)

Attempts to unload the module with the specified name.  
Returns 1 on success and `undef` on fail.

### Parameters

* __module_name:__ the name of the module to be unloaded.

# API private methods

These methods are provided by the API package, but they are typically only used internally. Use them at your own risk.

# API::Module methods

These methods of API::Module are used to manage modules.
