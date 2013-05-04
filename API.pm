# Copyright (c) 2012-13, Mitchell Cooper
# API: loads, unloads, and manages modules.
#
# This is API engine, an API manager written in Perl. it provides a modular
# programming interface to applications written in Perl. API engine is
# based on API.pm from the following software (in order chronologically descending)
#
# ... UICd, the official Universal Internet Chat server daemon
# ... juno5, the fifth version of juno-ircd, an IRC daemon written in Perl
# ... ntirc, a graphical WebKit-powered modular IRC client based upon libirc
# ... foxy-java, an event-driven modular IRC bot based upon libirc
# ... juno-mesh, the fourth version of juno-ircd, an IRC daemon written in Perl
# ... juno3, the third version of juno-ircd, an IRC daemon written in Perl
# ... juno2, a fully-featured, modular IRC daemon written entirely in Perl
#
package API;

use warnings;
use strict;
use utf8;
use feature 'switch';

use Scalar::Util 'blessed';

our $VERSION = '1.9';
our $main_api;

# API->new(
#     log_sub  => sub { },
#     mod_dir  => 'mod',
#     base_dir => 'lib/API/Base'
# );
# create a new API instance.
sub new {
    my ($class, %opts) = @_;
    my $api = bless \%opts, $class;
    $api->{loaded}       = [];
    $api->{loaded_bases} = [];
    return $main_api = $api;
}

# log.
sub log2 {
    my ($api, $msg) = @_;
    $api->{log_sub}($msg) if $api->{log_sub};
}

# load a module.
sub load_module {
    my ($api, $name, $parent) = @_;
    my $is_dir;
    
    # parent must be a module object.
    undef $parent if !ref $parent || !$parent->isa('API::Module');
    
    # the directory in which the module file is located.
    my $mod_dir = $parent ? $parent->{dir}.q(/submodules) : $api->{mod_dir};

    # if we haven't already, load API::Module.
    require API::Module if !API::Module->can('new');

    # make sure it hasn't been loaded previously.
    foreach my $mod (@{$api->{loaded}}) {
        next unless $mod->{name} eq $name;
        $api->log2("module '$name' appears to be loaded already.");
        return;
    }
    
    my $loc  = $name; $loc =~ s/::/\//g;
    my $file = $mod_dir.q(/).$loc.q(.pm);
    my $dir  = $mod_dir.q(/).$loc.q(.module);
    
    # first, make sure it exists.
    if (!-f $file) {
    
        # okay, the file does not exist. perhaps it is a .module directory.
        # also ensure that a 'module.pm' is present.
        if (-d $dir && -f "$dir/module.pm") {
            $is_dir = 1;
            $file   = "$dir/module.pm";
        }
        
        # can't find a directory either.
        else {
            $api->log2("could not locate '$name' module");
            return;
        }
        
    }

    # load the module.
    $api->log2("loading module '$name'");
    my $module = do $file;
    
    # error in do().
    if (!$module) {
        $api->log2("couldn't load $file: ".($! ? $! : $@));
        class_unload("API::Module::${name}");
        return;
    }

    # make sure it returned an API::Module.
    if (!blessed($module) || !$module->isa('API::Module')) {
        $api->log2("module '$name' did not return an API::Module object.");
        class_unload("API::Module::${name}");
        return;
    }

    # second check that the module doesn't exist already.
    # we really should check this earlier as well, seeing as subroutines and other symbols
    # could have been changed beforehand. this is just a double check.
    foreach my $mod (@{$api->{loaded}}) {
        next unless $mod->{package} eq $module->{package};
        $api->log2("module '$$module{name}' appears to be loaded already.");
        class_unload("API::Module::${name}");
        return;
    }

    # load the requirements if they are not already.
    $api->load_requirements($module)
           or $api->log2("$name: could not satisfy dependencies: ".($! ? $! : $@))
          and class_unload("API::Module::${name}")
          and return;

    # it is now time to load any other modules this module depends on.
    if ($module->{depends}) {
        foreach my $mod_name (@{$module->{depends}}) {
            # TODO: this currently does not support dependence of submodules.
            last if $api->get_module($mod_name); # already loaded.
            $api->load_module($mod_name)
            or  $api->log2("cannot load '$name' because it depends on '$mod_name' which was not loaded")
            and return;
        }
    }

    # initialize the module, giving up if it returns a false value.
    $api->log2("$name: initializing module");
    if (!eval { $module->{initialize}->() }) {
        $api->log2($@ ? "module '$name' failed with error: $@" : "module '$name' refused to load");
        class_unload("API::Module::${name}");
        return;
    }
    
    # all loading and checks completed with no error.
    push @{$api->{loaded}}, $module;
    $module->{api}    = $api;
    $module->{file}   = $file;
    $module->{dir}    = $dir;
    $module->{is_dir} = 1 if $is_dir;
    
    # set family hierarchy.
    if ($parent) {
        $module->{parent} = $parent;
        $parent->{children} ||= [];
        push @{$parent->{children}}, $module;
    }
    
    # call ->_load on bases.
    call_loads($module);

    $api->log2("module '$name' loaded successfully");
    
    # call after_load()
    if ($module->{after_load} && !eval { $module->{after_load}->() }) {
        $api->log2($@ ? "module '$name' after_load() failed with error: $@" : "module '$name' after_load() returned a false value; ignoring.");
        return;
    }
    
    return 1;
    
}

# unload a module.
sub unload_module {
    my ($api, $name, $recursive) = @_;

    # find it..
    my $mod;
    
    # a module object was provided.
    if (ref $name && $name->isa('API::Module')) {
        $mod  = $name;
        $name = $mod->full_name;
    }
    
    # a name was provided.
    else {
        foreach my $module (@{$api->{loaded}}) {
            next unless $module->{name} eq $name;
            $mod = $module;
            last;
        }
    }
    
    # couldn't find it.
    if (!$mod) {
        $api->log2("cannot unload module '$name' because it does not exist");
        return;
    }
    
    $api->log2("unloading module '$name'");
    
    # modules depend on this module.
    if (my @mods = $mod->dependent_modules) {
    
        # if this is not recursive, give up.
        if (!$recursive) {
            $api->log2("cannot unload module '$name' because loaded module(s) depend on it");
            return;
        }
        
        # we have recursive unloading enabled. we can unload all dependent modules.
        foreach my $depmod (@mods) {
            $api->unload_module($depmod->{name}, 1)
            or  $api->log2("cannot unload module '$name' because a dependent module could not be unloaded")
            and return;
        }
    
    }

    # first, unload the children of the module if it has any.
    if ($mod->{children} && ref $mod->{children} eq 'ARRAY') {
        foreach my $child (@{$mod->{children}}) {
            next if $api->unload_module($child);
            
            # not successful. if we can't unload the child, we can't unload the parent.
            $api->log2("cannot unload module '$name' because its child '$$child{name}' was not unloaded");
            return;
            
        }
    }

    # call void if exists.
    if ($mod->{void}) {
        $mod->{void}->() or
        $api->log2("module '$name' refused to unload")
        and return;
    }

    # unload all of its commands, loops, modes, etc.
    # then, unload the package.
    $api->call_unloads($mod);
    class_unload($mod->{package});

    # remove from @loaded_modules
    $api->{loaded} = [ grep { $_ != $mod } @{$api->{loaded}} ];
    
    # clear neverending references.
    delete $mod->{parent};
    delete $mod->{children};

    return 1;
}

# fetches a loaded module.
sub get_module {
    my ($api, $name) = @_;
    
    # first try full module name.
    foreach my $module (@{$api->{loaded}}) {
        return $module if $module->full_name eq $name;
    }
    
    # then try the lowest level name.
    foreach my $module (@{$api->{loaded}}) {
        return $module if $module->{name} eq $name;
    }
    
    return;
}

# reload a module.
sub reload_module {
    my ($api, $name) = @_;
    return $api->unload_module($name) && $api->load_module($name);
}

# load all of the API::Base requirements for a module.
sub load_requirements {
    my ($api, $mod) = @_;
    return unless $mod->{requires};
    return if ref $mod->{requires} ne 'ARRAY';

    $api->load_base($_) or return foreach @{$mod->{requires}};

    return 1
}

# attempt to load an API::Base.
sub load_base {
    my ($api, $base_name) = (shift, ucfirst shift);
    return 1 if $base_name ~~ @{$api->{loaded_bases}}; # already loaded
    $api->log2("loading base '$base_name'");
    
    # evaluate the file.
    do "$$api{base_dir}/$base_name.pm" or $api->log2("Could not load base '$base_name'") and return;
    
    # add it to API::Module's ISA.
    unshift @API::Module::ISA, "API::Base::$base_name";
    
    # store the base name to prevent loading it again.
    push @{$api->{loaded_bases}}, $base_name;
    
    return 1;
}

# register a an API::Base included as a module.
# $api->register_base_module(SomeBase => $some_module_object)
sub register_base_module {
    my ($api, $base_name, $module) = @_;
    return 1 if $base_name ~~ @{$api->{loaded_bases}}; # already loaded
    
    $api->log2($module->full_name." registered packaged base '$base_name'");

    unshift @API::Module::ISA, $module->{package};
    push @{$api->{loaded_bases}}, $base_name;
    $module->{base_loaded} = [$base_name, $module->{package}];
    
    return 1;
}

# call ->_load for each API::Base.
sub call_loads {
    my ($api, $module) = @_;
    foreach my $base (@API::Module::ISA) {
        $base->_load($module) if $base->can('_load');
    }
}

# call ->_unload for each API::Base.
sub call_unloads {
    my ($api, $module) = @_;
    foreach my $base (@API::Module::ISA) {
        $base->_unload($module) if $base->can('_unload');
    }
    
    # delete the base if necessary.
    return 1 unless defined(my $b = $module->{base_loaded});
    
    $api->log2('unloading base '.$b->[0]);
    $api->{loaded_bases} = [ grep { $_ ne $b->[0] } @{$api->{loaded_bases}} ];
    @API::Module::ISA = grep { $_ ne $b->[1] } @API::Module::ISA;
    
    return 1;
}

# unload a class and its symbols.
# from Class::Unload on CPAN.
# copyright (c) 2011 by Dagfinn Ilmari MannsÃ¥ker.
sub class_unload {
    my $class = shift;
    no strict 'refs';

    # Flush inheritance caches
    @{$class . '::ISA'} = ();

    my $symtab = $class.'::';
    # Delete all symbols except other namespaces
    for my $symbol (keys %$symtab) {
        next if $symbol =~ /\A[^:]+::\z/;
        delete $symtab->{$symbol};
    }

    my $inc_file = join( '/', split /(?:'|::)/, $class ) . '.pm';
    delete $INC{ $inc_file };

    return 1
}

1
