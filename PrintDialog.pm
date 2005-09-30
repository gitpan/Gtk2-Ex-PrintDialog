# $Id: PrintDialog.pm,v 1.4 2005/09/30 10:53:23 jodrell Exp $
# Copyright (c) 2005 Gavin Brown. All rights reserved. This program is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself.
package Gtk2::Ex::PrintDialog;
use Carp;
use File::Basename qw(basename dirname);
use File::Temp qw(tmpnam);
use Gtk2;
use Net::CUPS;
use vars qw($VERSION $GETTEXT $LPR $PRINTCMD $PS2PDF $PDFCMD);
use strict;

our $VERSION	= '0.01';
our $GETTEXT	= 0;
our $CUPS	= 0;
our $LPR	= 'lpr';
our $PRINTCMD	= which($LPR);
our $PS2PDF	= 'ps2pdf';
our $PDFCMD	= which($PS2PDF);

BEGIN {
	eval {
		require Locale::gettext;
		$GETTEXT = 1;
	};
}

*new = \&Glib::Object::new;

Glib::Type->register(
	Gtk2::Dialog::,
	__PACKAGE__,
);

sub INIT_INSTANCE {
	my $self = shift;
	$self->add_buttons(
		'gtk-cancel'		=> 'cancel',
		#'gtk-print-preview'	=> 0, not implemented just yet
		'gtk-print'		=> 1,
	);

	$self->signal_connect('response', sub { $self->response($_[1]) ; return 1 });

	$self->set_title(_('Print'));
	$self->set_icon_name('stock_print');
	$self->set_modal(1);
	$self->set_resizable(0);


	$self->{opts_label} = Gtk2::Label->new;
	$self->{opts_label}->set_use_markup(1);
	$self->{opts_label}->set_markup(sprintf('<span weight="bold">%s</span>', _('Print to:')));
	$self->{opts_label}->set_alignment(0, 0);


	$self->{opt_print_printer}	= Gtk2::RadioButton->new_with_label(undef, _('Printer:'));
	$self->{opt_print_command}	= Gtk2::RadioButton->new_with_label($self->{opt_print_printer}, _('Command:'));
	$self->{opt_print_pdf}		= Gtk2::RadioButton->new_with_label($self->{opt_print_printer}, _('PDF File:'));
	$self->{opt_print_file}		= Gtk2::RadioButton->new_with_label($self->{opt_print_printer}, _('File:'));


	# populate the printer combo:
	$self->{opt_printer_combo} = Gtk2::ComboBox->new_text;
	my @printers = grep { defined } cupsGetPrinters();
	# no printers, or cups not installed, fall through to the command mode:
	if (scalar(@printers) < 1) {
		$self->{opt_print_printer}->set_sensitive(undef);
		$self->{opt_printer_combo}->set_sensitive(undef);
		$self->{opt_print_command}->set_active(1);

	} else {
		map { $self->{opt_printer_combo}->append_text($_) } @printers;
		$self->{opt_printer_combo}->set_active(0);

	}


	# if lpr isn't in $PATH, let the user enter another command:
	$self->{opt_command_entry} = Gtk2::Entry->new;
	$self->{opt_command_entry}->set_text(-x $PRINTCMD ? $PRINTCMD : $LPR);


	$self->{opt_pdf_entry}	= Gtk2::Entry->new;
	$self->{opt_pdf_entry}->set_editable(0);
	$self->{opt_pdf_entry}->set_text(sprintf('%s/output.pdf', Glib::get_home_dir));

	$self->{pdf_entry_button} = Gtk2::Button->new;
	$self->{pdf_entry_button}->add(Gtk2::HBox->new);
	$self->{pdf_entry_button}->child->pack_start(Gtk2::Image->new_from_stock('gtk-save-as', 'button'), 0, 0, 0);
	$self->{pdf_entry_button}->child->pack_start(Gtk2::Label->new_with_mnemonic(_('_Browse..')), 1, 1, 0);
	$self->{pdf_entry_button}->signal_connect('clicked', sub { $self->choose_pdf_dialog });

	$self->{pdf_entry_box} = Gtk2::HBox->new;
	$self->{pdf_entry_box}->set_spacing(6);
	$self->{pdf_entry_box}->pack_start($self->{opt_pdf_entry}, 1, 1, 0);
	$self->{pdf_entry_box}->pack_start($self->{pdf_entry_button}, 0, 0, 0);

	if (!-x $PDFCMD) {
		$self->{opt_print_pdf}->set_sensitive(undef);
		$self->{opt_pdf_entry}->set_sensitive(undef);
		$self->{pdf_entry_button}->set_sensitive(undef);
	}


	$self->{opt_file_entry}	= Gtk2::Entry->new;
	$self->{opt_file_entry}->set_editable(0);
	$self->{opt_file_entry}->set_text(sprintf('%s/output.ps', Glib::get_home_dir));

	$self->{file_entry_button} = Gtk2::Button->new;
	$self->{file_entry_button}->add(Gtk2::HBox->new);
	$self->{file_entry_button}->child->pack_start(Gtk2::Image->new_from_stock('gtk-save-as', 'button'), 0, 0, 0);
	$self->{file_entry_button}->child->pack_start(Gtk2::Label->new_with_mnemonic(_('_Browse..')), 1, 1, 0);
	$self->{file_entry_button}->signal_connect('clicked', sub { $self->choose_file_dialog });

	$self->{file_entry_box} = Gtk2::HBox->new;
	$self->{file_entry_box}->set_spacing(6);
	$self->{file_entry_box}->pack_start($self->{opt_file_entry}, 1, 1, 0);
	$self->{file_entry_box}->pack_start($self->{file_entry_button}, 0, 0, 0);


	$self->{opts_table} = Gtk2::Table->new(5, 2, 0);
	$self->{opts_table}->set_col_spacings(6);
	$self->{opts_table}->set_row_spacings(6);

	$self->{opts_table}->attach($self->{opt_print_printer},	0, 1, 0, 1, 'fill', 'fill', 0, 0);
	$self->{opts_table}->attach($self->{opt_printer_combo},	1, 2, 0, 1, 'fill', 'fill', 0, 0);

	$self->{opts_table}->attach($self->{opt_print_command},	0, 1, 1, 2, 'fill', 'fill', 0, 0);
	$self->{opts_table}->attach($self->{opt_command_entry},	1, 2, 1, 2, 'fill', 'fill', 0, 0);

	$self->{opts_table}->attach($self->{opt_print_pdf},	0, 1, 2, 3, 'fill', 'fill', 0, 0);
	$self->{opts_table}->attach($self->{pdf_entry_box},	1, 2, 2, 3, 'fill', 'fill', 0, 0);

	$self->{opts_table}->attach($self->{opt_print_file},	0, 1, 3, 4, 'fill', 'fill', 0, 0);
	$self->{opts_table}->attach($self->{file_entry_box},	1, 2, 3, 4, 'fill', 'fill', 0, 0);

	# these seems to be needed to fix the layout of the table...
	my $label = Gtk2::Label->new;
	$label->set_size_request(0, 0);
	$self->{opts_table}->attach($label,			0, 2, 3, 4, 'expand', 'fill', 0, 0);

	my $hbox = Gtk2::HBox->new;
	$hbox->pack_start(Gtk2::Label->new(' ' x 4), 0, 0, 0);
	$hbox->pack_start($self->{opts_table}, 1, 1, 0);

	$self->{vbox} = Gtk2::VBox->new;
	$self->{vbox}->set_border_width(6);
	$self->{vbox}->set_spacing(6);
	$self->{vbox}->pack_start($self->{opts_label}, 0, 0, 0);
	$self->{vbox}->pack_start($hbox, 1, 1, 0);

	$self->{vbox}->show_all;

	$self->vbox->pack_start($self->{vbox}, 1, 1, 0);
	
}

sub choose_file_dialog {
	my $self = shift;
	my $dialog = Gtk2::FileChooserDialog->new(
		_('Choose File'),
		$self,
		'save',
		'gtk-cancel'	=> 'cancel',
		'gtk-ok'	=> 'ok',
	);
	$dialog->set_local_only(1);
	$dialog->set_modal(1);
	$dialog->set_icon_name('stock_print');
	$dialog->set_current_folder(dirname($self->{opt_file_entry}->get_text));
	$dialog->set_current_name(basename($self->{opt_file_entry}->get_text));
	$dialog->signal_connect('response', sub {
		$self->{opt_file_entry}->set_text($dialog->get_filename) if ($_[1] eq 'ok');
		$dialog->destroy;
	});
	$dialog->run;
}

sub choose_pdf_dialog {
	my $self = shift;
	my $dialog = Gtk2::FileChooserDialog->new(
		_('Choose File'),
		$self,
		'save',
		'gtk-cancel'	=> 'cancel',
		'gtk-ok'	=> 'ok',
	);
	$dialog->set_local_only(1);
	$dialog->set_modal(1);
	$dialog->set_icon_name('stock_print');
	$dialog->set_current_folder(dirname($self->{opt_pdf_entry}->get_text));
	$dialog->set_current_name(basename($self->{opt_pdf_entry}->get_text));
	$dialog->signal_connect('response', sub {
		$self->{opt_file_entry}->set_text($dialog->get_filename) if ($_[1] eq 'ok');
		$dialog->destroy;
	});
	$dialog->run;
}

sub response {
	my ($self, $response) = @_;

	if ($response eq 'cancel') {
		$self->destroy;

	} elsif ($response == 0) {
		$self->preview;

	} elsif ($response == 1) {
		$self->print;
		$self->destroy;

	} else {
		carp("Unknown response ID '$response'");

	}

	return 1;
}

sub preview {
}

sub print {
	my $self = shift;

	if ($self->{file} eq '' && $self->{data} eq '') {
		carp("Error: no data provided!");
		return undef;
	}

	$self->set_sensitive(undef);
	$self->window->set_cursor(Gtk2::Gdk::Cursor->new('watch'));
	Gtk2->main_iteration while (Gtk2->events_pending);

	if ($self->{opt_print_printer}->get_active) {
		$self->print_to_printer;

	} elsif ($self->{opt_print_command}->get_active) {
		$self->print_to_command;

	} elsif ($self->{opt_print_pdf}->get_active) {
		$self->print_to_pdf;

	} elsif ($self->{opt_print_file}->get_active) {
		$self->print_to_file;

	}

	$self->set_sensitive(1);
	$self->window->set_cursor(Gtk2::Gdk::Cursor->new('left_ptr'));

	return 1;
}

sub print_to_printer {
	my $self = shift;

	my $filename = tmpnam();
	open(TMPFILE, ">$filename");
	print TMPFILE $self->get_data;
	close(TMPFILE);

	cupsPrintFile($self->{opt_printer_combo}->get_active_text, $filename, ref($self), {});
	unlink($filename);

	return 1;
}

sub print_to_pdf {
	my $self = shift;
	my $cmd = sprintf('%s - "%s"', $PDFCMD, $self->{opt_pdf_entry}->get_text);
	return $self->_print_to_command($cmd);
}

sub print_to_command {
	my $self = shift;
	return $self->_print_to_command($self->{opt_command_entry}->get_text);
}

sub _print_to_command {
	my ($self, $cmd) = @_;

	if (!open(CMD, "|$cmd")) {
		my $dialog = Gtk2::MessageDialog->new(
			$self,
			'modal',
			'error',
			'ok',
			_('Error printing to command!'),
		);
		$dialog->format_secondary_markup(sprintf(_("Cannot run '%s': %s"), $cmd, $!));
		$dialog->signal_connect('response', sub { $dialog->destroy });
		$dialog->run;

	} else {
		print CMD $self->get_data;
		close(CMD);
		return 1;

	}
}

sub print_to_file {
	my $self = shift;

	my $file = $self->{opt_file_entry}->get_text;
	if (!open(DEST, ">$file")) {
		my $dialog = Gtk2::MessageDialog->new(
			$self,
			'modal',
			'error',
			'ok',
			_('Error printing to file!'),
		);
		$dialog->format_secondary_markup(_('Cannot write to %s: %s', $file, $!));
		$dialog->signal_connect('response', sub { $dialog->destroy });
		$dialog->run;

	} else {
		print DEST $self->get_data;
		close(DEST);
		return 1;

	}
}

sub set_filename {
	my ($self, $file) = @_;

	if (!open(FILE, $file)) {
		carp("Error opening '".$file."': $!");
		return undef;

	} else {
		binmode(FILE);
		$self->{data} = '';
		while (<FILE>) {
			$self->{data} .= $_;
		}
		close(FILE);
	}

	return 1;
}

sub get_filename {
	$_[0]->{file};
}

sub set_data {
	$_[0]->{data} = $_[1];
}

sub get_data {
	$_[0]->{data};
}

sub _ {
	my $text = shift;
	return ($GETTEXT == 1 ? Locale::gettext::gettext($text) : $text);
}

sub which {
	my $cmd = shift;
	foreach my $dir (split(/:/, $ENV{PATH})) {
		my $path = sprintf('%s/%s', $dir, $cmd);
		return $path if (-x $path);
	}
	return undef;
}

1;

=pod

=head1 NAME

Gtk2::Ex::PrintDialog - a simple, pure Perl dialog for printing PostScript data in GTK+ applications.

=head1 SYNOPSIS

	use Gtk2::Ex::PrintDialog;

	my $dialog = Gtk2::Ex::PrintDialog->new;	# a new dialog

	$dialog->set_data($postscript_data);		# supply some postscript data

	$dialog->set_filename($postscript_file);	# get postscript from a file

	$dialog->run;					# show the dialog to the user

=head1 DESCRIPTION

This module implements a dialog widget that can be used to print PostScript
data on any CUPS-aware system. It is intended to be a lightweight and
pure-perl alternative to the Gnome2::Print libraries.

The dialog itself is intended to comply with the GNOME Human Interface
Guidelines (HIG), and will gracefully fail if no printers have been installed,
by providing an option to print to the C<lpr> command. If C<lpr> isn't
installed either, the user can opt to print to another command, to a PDF file
or to a PostScript file.

=head1 OBJECT HIERARCHY

  Glib::Object
  +----Gtk2::Object
       +----Gtk2::Widget
            +----Gtk2::Container
                 +----Gtk2::Bin
                      +----Gtk2::Window
                           +----Gtk2::Dialog
                                +----Gtk2::Ex::PrintDialog

=head1 METHODS

	my $dialog = Gtk2::Ex::PrintDialog->new;

Returns an instance of C<Gtk2::Ex::PrintDialog>. These dialogs are subclasse
of C<Gtk2::Dialog> so all corresponding methods, signals and properties from
that class are also available.

The dialog will handle user actions itself so you will probably not need to
connect to any signals.

	$dialog->set_data($data);

This tells the dialog to use the PostScript data in C<$data>. This might be
PostScript data you create yourself, or from another application. This data
can subsequently retrieved using C<get_data()>.

	$dialog->set_filename($file);

This tells the dialog to use the PostScript data in C<$file>. The file name
can be subsequently retrieved using C<get_filename()>. The contents
of the file are read into memory when C<set_filename()> is called, so any
subequent calls to C<get_data()> will return the contents of C<$file>.

=head1 LOCALISATION ISSUES

If the C<Locale::gettext> module is available on the system, and your
application uses it, all the strings used in the dialog will be automagically
translated, as long as these default values are translated in your .mo files.

=head1 PREREQUISITES

=over

=item L<Gtk2>

=item L<Locale::gettext> (recommended)

=item L<Net::CUPS>

=item Ghostscript, for the C<ps2pdf> command (recommended)

=back

=head1 SEE ALSO

L<Gnome2::Print>

=head1 TO DO

=over

=item Implement a "Print Preview" function, maybe using Poppler.

=back

=head1 AUTHOR

Gavin Brown (gavin dot brown at uk dot com)  

=head1 COPYRIGHT

(c) 2005 Gavin Brown. All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.     

=cut
