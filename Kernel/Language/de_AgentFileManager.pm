# --
# Kernel/Language/de_AgentFileManager.pm - the de language for file manager
# Copyright (C) 2001-2009 OTRS AG, http://otrs.org/
# --
# $Id: de_AgentFileManager.pm,v 1.7 2009/05/19 14:08:30 tt Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_AgentFileManager;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.7 $) [1];

sub Data {
    my ( $Self, %Param ) = @_;

    # $$START$$

    $Self->{Translation}->{'Create Directory'} = 'Verzeichnis erstellen';
    $Self->{Translation}->{'File Upload'}      = 'Datei Upload';
    $Self->{Translation}->{'Create'}           = 'Erstellen';
    $Self->{Translation}->{'Up'}               = 'Auf';
    $Self->{Translation}->{'Parent Directory'} = 'Übergeordnetes Verzeichnis';
    $Self->{Translation}->{'FileManager'}      = 'FileManager';
    $Self->{Translation}->{'Web File Manager'} = 'Online Dateiverwaltung';
    $Self->{Translation}->{'A webbased file manager'} = 'Ein webbasierender Datei-Manager';

    # $$STOP$$

    return 1;
}
1;
