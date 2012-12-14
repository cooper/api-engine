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
    
    # if requires was provided and is not an arrayref, it is a single module string.
    if (defined $opts{requires} && ref $opts{requires} ne 'ARRAY') {
        $opts{requires} = [ $opts{requires} ];
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
}

1
