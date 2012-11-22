# Copyright (c) 2012, Mitchell Cooper
# based on API::Module from juno-ircd version 5.0.
package API::Module;

use warnings;
use strict;
use utf8;
use v5.10;

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
    $opts{requires} = [$opts{requires}] if $opts{requires} && ref $opts{requires} ne 'ARRAY';

    # make sure all required options are present.
    foreach my $what (qw|name version description initialize|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $API::main_api->log2("module $opts{name} does not have '$what' option.");
        return
    }

    # initialize and void must be code references.
    if (!defined ref $opts{initialize} or ref $opts{initialize} ne 'CODE') {
        $API::main_api->log2("module $opts{name} didn't supply initialize CODE.");
        return
    }
    if ((defined $opts{void}) && (!defined ref $opts{void} or ref $opts{void} ne 'CODE')) {
        $API::main_api->log2("module $opts{name} provided void, but it is not CODE.");
        return
    }

    # set package name.
    $opts{package} = caller;

    return bless \%opts, $class;
}

1
