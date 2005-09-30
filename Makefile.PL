#!/usr/bin/perl
# $Id: Makefile.PL,v 1.3 2005/09/30 15:05:44 jodrell Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Gtk2::Ex::PrintDialog',
    'VERSION_FROM'	=> 'PrintDialog.pm',
    'PREREQ_FATAL'	=> 1,
    'PREREQ_PM'		=> {
        File::Basename	=> 0,
        File::Temp	=> 0,
        Gtk2		=> 0,
        Locale::gettext	=> 0,
        Net::CUPS	=> 0,
    },
);
