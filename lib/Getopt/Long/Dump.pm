package Getopt::Long::Dump;

our $DATE = '2014-12-21'; # DATE
our $VERSION = '0.03'; # VERSION

use 5.010;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(dump_getopt_long_script);

our %SPEC;

$SPEC{dump_getopt_long_script} = {
    v => 1.1,
    summary => 'Run a Getopt::Long-based script but only to '.
        'dump the spec',
    description => <<'_',

This function runs a CLI script that uses `Getopt::Long` but monkey-patches
beforehand so that `run()` will dump the object and then exit. The goal is to
get the object without actually running the script.

This can be used to gather information about the script and then generate
documentation about it or do other things (e.g. `App::shcompgen` to generate a
completion script for the original script).

CLI script needs to use `Getopt::Long`. This is detected currently by a simple
regex. If script is not detected as using `Getopt::Long`, status 412 is
returned.

Will return the `Getopt::Long` specification.

_
    args => {
        filename => {
            summary => 'Path to the script',
            req => 1,
            schema => 'str*',
        },
        libs => {
            summary => 'Libraries to unshift to @INC when running script',
            schema  => ['array*' => of => 'str*'],
        },
    },
};
sub dump_getopt_long_script {
    require Capture::Tiny;
    require Getopt::Long::Util;
    require UUID::Random;

    my %args = @_;

    my $filename = $args{filename} or return [400, "Please specify filename"];
    my $detres = Getopt::Long::Util::detect_getopt_long_script(
        filename => $filename);
    return $detres if $detres->[0] != 200;
    return [412, "File '$filename' is not script using Getopt::Long (".
        $detres->[3]{'func.reason'}.")"] unless $detres->[2];

    my $libs = $args{libs} // [];

    my $tag = UUID::Random::generate();
    my @cmd = (
        $^X, (map {"-I$_"} @$libs),
        "-MGetopt::Long::Patch::DumpAndExit=-tag,$tag",
        $filename,
        "--version",
    );
    my ($stdout, $stderr, $exit) = Capture::Tiny::capture(
        sub { system @cmd },
    );

    my $spec;
    if ($stdout =~ /^# BEGIN DUMP $tag\s+(.*)^# END DUMP $tag/ms) {
        $spec = eval $1;
        if ($@) {
            return [500, "Script '$filename' detected as using ".
                        "Getopt::Long, but error in eval-ing captured ".
                            "option spec: $@, raw capture: <<<$1>>>"];
        }
        if (ref($spec) ne 'HASH') {
            return [500, "Script '$filename' detected as using ".
                        "Getopt::Long, but didn't get a hash option spec, ".
                            "raw capture: stdout=<<$stdout>>"];
        }
    } else {
        return [500, "Script '$filename' detected as using Getopt::Long, ".
                    "but can't capture option spec, raw capture: ".
                        "stdout=<<$stdout>>, stderr=<<$stderr>>"];
    }

    [200, "OK", $spec];
}

1;
# ABSTRACT: Run a Getopt::Long-based script but only to dump the spec

__END__

=pod

=encoding UTF-8

=head1 NAME

Getopt::Long::Dump - Run a Getopt::Long-based script but only to dump the spec

=head1 VERSION

This document describes version 0.03 of Getopt::Long::Dump (from Perl distribution Getopt-Long-Dump), released on 2014-12-21.

=head1 FUNCTIONS


=head2 dump_getopt_long_script(%args) -> [status, msg, result, meta]

Run a Getopt::Long-based script but only to dump the spec.

This function runs a CLI script that uses C<Getopt::Long> but monkey-patches
beforehand so that C<run()> will dump the object and then exit. The goal is to
get the object without actually running the script.

This can be used to gather information about the script and then generate
documentation about it or do other things (e.g. C<App::shcompgen> to generate a
completion script for the original script).

CLI script needs to use C<Getopt::Long>. This is detected currently by a simple
regex. If script is not detected as using C<Getopt::Long>, status 412 is
returned.

Will return the C<Getopt::Long> specification.

Arguments ('*' denotes required arguments):

=over 4

=item * B<filename>* => I<str>

Path to the script.

=item * B<libs> => I<array>

Libraries to unshift to @INC when running script.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Getopt-Long-Dump>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Getopt-Long-Dump>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Getopt-Long-Dump>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
