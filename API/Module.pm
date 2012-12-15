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

# returns true if the module depends on the passed module.
sub depends_on {
    my ($module, $mod) = @_;
    return scalar grep { $_ eq $mod->{name} } @{$module->{depends}};
}

# returns an array of modules that depend on this module.
sub dependent_modules {
    my $module = shift;
    my @depends;
    
    # look through each module.
    foreach my $mod (@{$mod->{api}{loaded}}) {
        next if !$mod->depends_on($module);
        push @depends, $mod;
    }
    
    return @depends;
}

1
