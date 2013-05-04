# Copyright (c) 2012, Mitchell Cooper
# based on API::Module from juno-ircd version 5.0.
package API::Module;

use warnings;
use strict;
use utf8;
use v5.10;

our $VERSION = $API::VERSION;
our @EXPORT;

# export/import.
sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = *{__PACKAGE__.'::'.$_} foreach @EXPORT;
}

sub new {
    my ($class, %opts) = @_;
    $opts{requires} ||= [];
    
    # if any of these were provided and are not an arrayref, it is a single string.
    foreach (qw|requires mod_depends|) {
        if (defined $opts{$_} && ref $opts{$_} ne 'ARRAY') {
            $opts{$_} = [ $opts{$_} ];
        }
    }
    
    # if no API is specified for some reason, default to the main API.
    $opts{api} ||= $API::main_api;
    
    # make sure all required options are present.
    foreach my $what (qw|name version description initialize api|) {
        next if defined $opts{$what};
        $opts{name} ||= 'unknown';
        $opts{api}->log2("module '$opts{name}' does not have '$what' option.");
        return
    }

    # initialize and void must be code references.
    if (ref $opts{initialize} ne 'CODE') {
        $opts{api}->log2("module '$opts{name}' supplied initialize, but it is not CODE.");
        return
    }
    if ((defined $opts{void}) && (!defined ref $opts{void} or ref $opts{void} ne 'CODE')) {
        $opts{api}->log2("module '$opts{name}' provided void, but it is not CODE.");
        return
    }

    # set package name.
    $opts{package} = caller;

    return bless \%opts, $class;
}

# loads a submodule.
sub load_submodule {
    my ($mod, $name) = @_;
    return $mod->{api}->load_module($name, $mod);
}

# returns the full name of a module, including parent modules.
# for example, a module named MyModule whose parent is ParentModule would return
# ParentModule.MyModule. If ParentModule's parent module were named FatherModule, this
# would return FatherModule.ParentModule.MyModule.
sub full_name {
    my $module = shift;
    
    # if this module has no parent, its full name is simply its name.
    return $module->{name} if !$module->{depends} || !scalar @{$module->{depends}};
 
    # it has a parent. use the parent's full name suffixed by module's this name.
    return $module->{parent}->full_name().q(.).$module->{name};   
    
}

# returns true if the module depends on the passed module.
# note: depends for submodules are written as 'parentMod.subMod'
sub depends_on {
    my ($module, $mod) = @_;
    return scalar grep { $_ eq $mod->full_name } @{$module->{depends}};
}

# returns an array of modules that depend on this module.
sub dependent_modules {
    my $module = shift;
    my @depends;
    
    # look through each module.
    foreach my $mod (@{$module->{api}{loaded}}) {
        next if !$mod->depends_on($module);
        push @depends, $mod;
    }
    
    return @depends;
}

# returns a unique callback name.
sub unique_callback {
    my ($module, $type, $name) = @_;
    my $mod_name = $module->full_name;
    $name        = defined $name ? q(.).$name : q();
    $module->{current_callback_id} ||= 0;
    my $next = $module->{current_callback_id}++;
    return "api.$mod_name.$type$name($next)";
}

1
