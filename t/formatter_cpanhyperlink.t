#!/usr/bin/perl -w
use strict;
use MojoMojo::Formatter::CPANHyperlink;

use Test::More tests => 6;

my $content = '{{cpan Moose}} is a great module';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '<a href="http://search.cpan.org/perldoc?Moose" class="external">Moose</a> is a great module', 'one-word module');

$content = '{{cpan Tie::IxHash}} should be in core';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '<a href="http://search.cpan.org/perldoc?Tie::IxHash" class="external">Tie::IxHash</a> should be in core', 'multi-word module');

$content = '{{cpan 2+3}} is not a valid module name';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '{{cpan 2+3}} is not a valid module name', 'invalid module name');

$content = '{{cpan 2::Pac}} is not a valid module name';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '{{cpan 2::Pac}} is not a valid module name', 'invalid module name');

$content = '{{cpan _::_}} is, maybe surprisingly, a valid module name';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '<a href="http://search.cpan.org/perldoc?_::_" class="external">_::_</a> is, maybe surprisingly, a valid module name', 'surprisingly valid module name');

$content = '{{cpan Moose}} is great, and so is {{cpan KiokuDB}}';
MojoMojo::Formatter::CPANHyperlink->format_content(\$content);
is($content, '<a href="http://search.cpan.org/perldoc?Moose" class="external">Moose</a> is great, and so is <a href="http://search.cpan.org/perldoc?KiokuDB" class="external">KiokuDB</a>', 'multiple calls per page');
