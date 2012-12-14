# Copyright (c) 2012, Mitchell Cooper
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

our $VERSION = 0.2;
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
    $api->{loaded} = [];
    return $main_api = $api;
}

# log.
sub log2 {
    my ($api, $msg) = @_;
    $api->{log_sub}($msg) if $api->{log_sub};
}

# load a module.
sub load_module {
    my ($api, $name) = @_;

    # if we haven't already, load API::Module.
    if (!$INC{'API/Module.pm'}) {
        require API::Module;
    }

    # make sure it hasn't been loaded previously.
    foreach my $mod (@{$api->{loaded}}) {
        next unless $mod->{name} eq $name;
        $api->log2("module '$name' appears to be loaded already.");
        return;
    }

    # load the module.
    $api->log2("loading module '$name'");
    my $loc    = $name; $loc =~ s/::/\//g;
    my $file   = $api->{mod_dir}.q(/).$loc.q(.pm);
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

    # load the requirements if they are not already
    $api->load_requirements($module)
          or  $api->log2("$name: could not satisfy dependencies: ".($! ? $! : $@))
          and class_unload("API::Module::${name}")
          and return;

    # initialize
    $api->log2("$name: initializing module");
    eval { $module->{initialize}->() } or
    $api->log2($@ ? "module '$name' failed with error: $@" : "module '$name' refused to load") and
    class_unload("API::Module::${name}") and
    return;
    
    # all loading and checks completed with no error.
    push @{$api->{loaded}}, $module;
    $module->{api} = $api;

    $api->log2("uicd module '$name' loaded successfully");
    return 1
}

# unload a module.
sub unload_module {
    my ($api, $name, $file) = @_;

    # find it..
    my $mod;
    foreach my $module (@{$api->{loaded}}) {
        next unless $module->{name} eq $name;
        $mod = $module;
        last;
    }

    if (!$mod) {
        $api->log2("cannot unload module '$name' because it does not exist");
        return
    }

    # call void if exists.
    if ($mod->{void}) {
        $mod->{void}->()
         or $api->log2("module '$$mod{name}' refused to unload")
         and return;
    }

    # unload all of its commands, loops, modes, etc.
    # then, unload the package.
    call_unloads($mod);
    class_unload($mod->{package});

    # remove from @loaded_modules
    $api->{loaded} = [ grep { $_ != $mod } @{$api->{loaded}} ];

    return 1
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
    my ($api, $base) = (shift, ucfirst shift);
    return 1 if $INC{"$$api{base_dir}/$base.pm"}; # already loaded
    $api->log2("loading base '$base'");
    do "$$api{base_dir}/$base.pm" or $api->log2("Could not load base '$base'") and return;
    unshift @API::Module::ISA, "API::Base::$base";
    return 1;
}

# call ->_unload for each API::Base.
sub call_unloads {
    my ($api, $module) = @_;
    $_->_unload($module) foreach @API::Module::ISA;
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
