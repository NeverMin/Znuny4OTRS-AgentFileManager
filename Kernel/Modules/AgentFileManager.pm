# --
# Kernel/Modules/AgentFileManager.pm - a file download manager
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: AgentFileManager.pm,v 1.18 2011/08/18 14:42:48 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentFileManager;

use strict;
use warnings;

use File::Glob ':glob';
use File::Copy;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.18 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed objects
    for (qw(ParamObject DBObject LayoutObject LogObject ConfigObject EncodeObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # config options
    $Self->{DataDir}  = $Self->{ConfigObject}->Get('FileManager::Root') . "/";
    $Self->{TrashDir} = $Self->{ConfigObject}->Get('FileManager::Trash')
        || $Self->{DataDir} . '/Trash/';
    $Self->{TrashDir} =~ s{<OTRS_FileManager::Root>}{$Self->{DataDir}}smx;

    $Self->{ReadAccessMap} = $Self->{ConfigObject}->Get('FileManager::ReadAccessMap')
        || { '/' => 'users' };
    $Self->{DeleteAccessMap} = $Self->{ConfigObject}->Get('FileManager::DeleteAccessMap')
        || { '/' => 'users' };
    $Self->{CreateAccessMap} = $Self->{ConfigObject}->Get('FileManager::CreateAccessMap')
        || { '/' => 'users' };

    # param init.
    $Self->{Location} = $Self->{ParamObject}->GetParam( Param => 'Location' ) || '/';
    $Self->{NewDir}   = $Self->{ParamObject}->GetParam( Param => 'NewDir' )   || '';
    $Self->{RmDir}    = $Self->{ParamObject}->GetParam( Param => 'RmDir' )    || '';
    $Self->{RmFile}   = $Self->{ParamObject}->GetParam( Param => 'RmFile' )   || '';

    # file and directory cleanup
    for (qw(DataDir TrashDir Location NewDir RmFile)) {
        $Self->{$_} =~ s/\.\.//g;
        $Self->{$_} =~ s/\/\//\//g;
    }

    return $Self;
}

sub SubCount {
    my ( $Self, %Param ) = @_;

    my $Count = 0;
    my @List  = glob("$Param{Directory}/*");
    for my $File (@List) {
        $Count++;
    }
    return $Count;
}

sub CheckPermission {
    my ( $Self, %Param ) = @_;

    # check permissions
    my $Access                          = 0;
    my $DirectoryFoundInPermissionTable = 0;
    if ( $Self->{ $Param{Type} } && ref( $Self->{ $Param{Type} } ) eq 'HASH' ) {
        for my $Dir ( keys %{ $Self->{ $Param{Type} } } ) {
            if (
                $Param{Location} =~ /^$Dir/
                && $Self->{"UserIsGroup[$Self->{$Param{Type}}->{$Dir}]"}
                && $Self->{"UserIsGroup[$Self->{$Param{Type}}->{$Dir}]"} eq 'Yes'
                )
            {

                #                print STDERR "Access $Param{Type} to $Dir\n";
                $Access = 1;
            }
            if ( $Param{Location} =~ /^$Dir/ ) {
                $DirectoryFoundInPermissionTable = 1;
            }
        }
    }
    if ( !$DirectoryFoundInPermissionTable ) {

        #        print STDERR "No group found for $Param{Type} base dir $Param{Location}\n";
        return 1;
    }
    if ( !$Access ) {

        #        print STDERR "No access $Param{Type} to $Param{Location}\n";
    }
    return $Access;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{DataDir} =~ m{ \\ }smx ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message =>
                "FileManager Root directory has the wrong syntax: $Self->{DataDir}, please check your config setting!\n"
                . "If you use a Windows system: Your path entry need the perl style.\n"
                . "Please replace all backslashes with slashes e.g. C:/Path/To/FileManager/Location/\n",
        );
    }

    # check root directory
    if ( !-e $Self->{DataDir} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message =>
                "FileManager Root directory doesn't exist: $Self->{DataDir}, please check your config setting!\n"
                . "So you find the setting:\n"
                . " o go to SysConfig in admin interface\n"
                . " o select group 'Filemanager' and sub group 'Core'\n"
                . " o now insert in FileManager::Root the filemanager root\n"
                . " o REMARK: If you use a Windows system: Your path entry need the perl style.\n"
                . "   Please replace all backslashes with slashes e.g. C:/Path/To/FileManager/Location/\n",
        );
    }

    # create permissions
    $Param{CreateAccessMap}
        = $Self->CheckPermission( Type => 'CreateAccessMap', Location => $Self->{Location} );

    # remove file
    if (
        $Self->{RmFile}
        && $Self->{Location}
        && $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $Self->{RmFile} )
        )
    {

        #print STDERR "unlink $Self->{DataDir}.'/'.$Self->{RmFile}\n";
        my $File = $Self->{DataDir} . $Self->{RmFile};
        $File =~ s/\/\//\//g;
        if ( $File !~ /^$Self->{TrashDir}/ ) {
            if ( !-e $Self->{TrashDir} ) {
                if ( !mkdir $Self->{TrashDir} ) {
                    return $Self->{LayoutObject}->ErrorScreen(
                        Message => "Can't create trash directory $Self->{TrashDir}: $!",
                    );
                }
            }
            my $NewFile = time() . $Self->{RmFile};
            $NewFile =~ s/(\\|\/)/__/g;
            if ( !move( $File, $Self->{TrashDir} . "/$NewFile" ) ) {
                return $Self->{LayoutObject}->ErrorScreen(
                    Message =>
                        "Can't move file $File to trash directory $Self->{TrashDir}/$NewFile: $!",
                );
            }
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=$Self->{Action}&Location="
                    . $Self->{LayoutObject}->LinkEncode( $Self->{Location} )
            );
        }
        elsif ( unlink $File ) {
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=$Self->{Action}&Location="
                    . $Self->{LayoutObject}->LinkEncode( $Self->{Location} )
            );
        }
        else {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Can't remove $File: $!",
            );
        }
    }

    # remove directory
    if (
        $Self->{RmDir}
        && $Self->{Location}
        && $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $Self->{RmDir} )
        )
    {

        #print STDERR "rmdir $Self->{RmDir}\n";
        my $Dir = $Self->{DataDir} . $Self->{RmDir};
        if ( rmdir $Dir ) {
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=$Self->{Action}&Location="
                    . $Self->{LayoutObject}->LinkEncode( $Self->{Location} )
            );
        }
        else {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Can't remove $Dir: $!",
            );
        }
    }

    # create new directory
    if (
        $Self->{Location}
        && $Self->{NewDir}
        && $Self->CheckPermission(
            Type     => 'CreateAccessMap',
            Location => $Self->{Location} . '/' . $Self->{NewDir}
        )
        )
    {

        #print STDERR "mkdir $Self->{DataDir}.$Self->{Location}.'/'.$Self->{NewDir}\n";
        my $Dir = $Self->{DataDir} . $Self->{Location} . '/' . $Self->{NewDir};
        if ( mkdir $Dir ) {
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=$Self->{Action}&Location="
                    . $Self->{LayoutObject}->LinkEncode( $Self->{Location} . '/' . $Self->{NewDir} )
            );
        }
        else {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Can't create $Dir: $!",
            );
        }
    }

    # get attachment
    my %UploadStuff = $Self->{ParamObject}->GetUploadAll(
        Param  => 'file_upload',
        Source => 'String',
    );
    if (
        $Self->{Location}
        && %UploadStuff
        && $Self->CheckPermission( Type => 'CreateAccessMap', Location => $Self->{Location} )
        )
    {
        my $File = $Self->{DataDir} . $Self->{Location} . '/' . $UploadStuff{Filename};
        if ( -e $File ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Can't write $File, file already exists!",
            );
        }
        elsif ( open my $Out, '>', $File ) {
            print $Out $UploadStuff{Content};
            close $Out;
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=$Self->{Action}&Location="
                    . $Self->{LayoutObject}->LinkEncode( $Self->{Location} )
            );
        }
        else {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Can't write $File: $!",
            );
        }
    }

    # download a file
    my $File = $Self->{DataDir} . $Self->{Location};
    if (
        !-d $File
        && $Self->CheckPermission( Type => 'ReadAccessMap', Location => $Self->{Location} )
        )
    {

        # mime types
        my %MimeType = qw(
            pdf application/pdf
            pgp application/pgp
            ps application/postscript
            rtf application/rtf
            dvi application/x-dvi
            gtar application/x-gtar
            gz application/x-gunzip
            latex application/x-latex
            tar application/x-tar
            tcl application/x-tcl
            tex application/x-tex
            texi application/x-texinfo
            zip application/zip

            wav audio/x-wav

            gif image/gif
            jpg image/jpeg
            png image/png
            tif image/tiff
            tiff image/tiff

            html text/html
            htm text/html
            css text/html
            pl text/plain
            pm text/plain
            php text/plain
            cpp text/plain
            c text/plain
            cc text/plain
            asc text/plain
            txt text/plain
            text text/plain
            rtx text/richtext
            rtf text/rtf
            vcf text/x-vcard
            sgml text/sgml
            sgm text/sgml
            xml text/xml
            dtd text/xml
            xsl text/xml

            doc application/msword
            dot application/msword
            xls application/excel

            mpg video/mpeg
            mov video/quicktime
            avi video/x-msvideo

        );
        my $FileMimeType = 'application/octet-stream';
        my $FileExt      = $File;
        $FileExt =~ s/^.*\.(.+?)$/$1/;
        if ( $MimeType{ lc($FileExt) } ) {
            $FileMimeType = $MimeType{ lc($FileExt) };
        }
        my $FileShort = $File;
        $FileShort =~ s/^.*\/(.+?)$/$1/g;

        # get file
        my $Content = '';
        use bytes;
        if ( open my $Infoin, '<', $File ) {
            while ( my $line = <$Infoin> ) {
                $Content .= $line;
            }
            close $Infoin;
        }
        else {
            $Self->{LayoutObject}->FatalError( Message => "$_" );
        }
        no bytes;

        # return file
        return $Self->{LayoutObject}->Attachment(
            ContentType => $FileMimeType,
            Content     => $Content,
            Filename    => $FileShort,
            Type        => 'inline',
        );
    }

    # else, view directory
    $Self->{LayoutObject}->Block(
        Name => 'View',
        Data => {
            %Param,
            Location => $Self->{Location},
        },
    );
    my $Dir = $Self->{DataDir} . $Self->{Location};

    # check if directory exists
    if ( !-e $Dir ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "No such directory: $Dir",
        );
    }

    # get directory index
    my @List = glob("$Dir/*");

    # add upper director
    if ( $Self->{Location} && $Self->{Location} ne '/' ) {
        $Dir =~ s/^(.*\/).+?$/$1/;
        push @List, $Dir;
    }

    # sort files
    #    @List = sort @List;
    my @Directory = ();
    my @File      = ();
    for my $File ( sort @List ) {
        if ( -d $File ) {
            push @Directory, $File;
        }
        else {
            push @File, $File;
        }
    }
    @List = ( @Directory, @File );

    # charset handling
    for my $File (@List) {
        $Self->{EncodeObject}->Encode( \$File );
    }

    # show the files and directories
    my $Css = 'searchpassive';
    for my $File (@List) {
        my $Delete = '';
        my $VFile  = $File;
        $VFile =~ s/$Self->{DataDir}//;
        $VFile =~ s/\/\//\//g;
        $Css = $Css eq 'searchactive' ? 'searchpassive' : 'searchactive';

        # check read permission
        if ( !$Self->CheckPermission( Type => 'ReadAccessMap', Location => $VFile ) ) {
            next;
        }

        if ( $Self->{ConfigObject}->Get("FileManager::ListType") ) {

            # show upper directory link
            if ( $List[0] eq $File && $Self->{Location} && $Self->{Location} ne '/' ) {
                $Self->{LayoutObject}->Block(
                    Name => 'ParentDirectory',
                    Data => {
                        Name      => 'Up',
                        NameShown => 'Parent Directory',
                        File      => $VFile,
                    },
                );
            }

            # show directories
            elsif ( -d $File ) {
                my $Count = $Self->SubCount( Directory => $File );
                if ( $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $VFile ) ) {
                    $Delete = 'Delete';
                }
                if ( $Self->CheckPermission( Type => 'ReadAccessMap', Location => $VFile ) ) {
                    my @path = split( /\//, $VFile );
                    $Self->{LayoutObject}->Block(
                        Name => 'Directory',
                        Data => {
                            Name      => $VFile . '/',
                            NameShown => pop(@path) . "/",
                            File      => $VFile . '/',
                            Delete    => $Delete,
                            Location  => $Self->{Location},
                            Count     => "($Count)",
                            Css       => $Css,
                        },
                    );
                }
            }

            # show files
            else {
                my $FileSize = -s $File || 0;
                $FileSize = $FileSize - 30 if ( $FileSize > 30 );
                if ( $FileSize > ( 1024 * 1024 ) ) {
                    $FileSize = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
                }
                elsif ( $FileSize > 1024 ) {
                    $FileSize = sprintf "%.1f KBytes", ( ( $FileSize / 1024 ) );
                }
                else {
                    $FileSize = $FileSize . ' Bytes';
                }
                if ( $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $VFile ) ) {
                    $Delete = 'Delete';
                }
                if ( $Self->CheckPermission( Type => 'ReadAccessMap', Location => $VFile ) ) {
                    my @path = split( /\//, $VFile );
                    $Self->{LayoutObject}->Block(
                        Name => 'File',
                        Data => {
                            Name      => $VFile,
                            NameShown => pop(@path),
                            File      => $VFile,
                            Size      => $FileSize,
                            Delete    => $Delete,
                            Location  => $Self->{Location},
                            Css       => $Css,
                        },
                    );
                }
            }
        }
        else {

            # show upper directory link
            if ( $List[0] eq $File && $Self->{Location} && $Self->{Location} ne '/' ) {
                $Self->{LayoutObject}->Block(
                    Name => 'ParentDirectory',
                    Data => {
                        Name      => 'Up',
                        NameShown => 'Parent Directory',
                        File      => $VFile,
                        Css       => $Css,
                    },
                );
            }

            # show directories
            elsif ( -d $File ) {
                my $Count = $Self->SubCount( Directory => $File );
                if ( $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $VFile ) ) {
                    $Delete = 'Delete';
                }
                if ( $Self->CheckPermission( Type => 'ReadAccessMap', Location => $VFile ) ) {
                    $Self->{LayoutObject}->Block(
                        Name => 'Directory',
                        Data => {
                            Name      => $VFile . '/',
                            NameShown => $VFile . '/',
                            File      => $VFile . '/',
                            Delete    => $Delete,
                            Location  => $Self->{Location},
                            Count     => "($Count)",
                            Css       => $Css,
                        },
                    );
                }
            }

            # show files
            else {
                my $FileSize = -s $File || 0;
                $FileSize = $FileSize - 30 if ( $FileSize > 30 );
                if ( $FileSize > ( 1024 * 1024 ) ) {
                    $FileSize = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
                }
                elsif ( $FileSize > 1024 ) {
                    $FileSize = sprintf "%.1f KBytes", ( ( $FileSize / 1024 ) );
                }
                else {
                    $FileSize = $FileSize . ' Bytes';
                }
                if ( $Self->CheckPermission( Type => 'DeleteAccessMap', Location => $VFile ) ) {
                    $Delete = 'Delete';
                }
                if ( $Self->CheckPermission( Type => 'ReadAccessMap', Location => $VFile ) ) {
                    $Self->{LayoutObject}->Block(
                        Name => 'File',
                        Data => {
                            Name      => $VFile,
                            NameShown => $VFile,
                            File      => $VFile,
                            Size      => $FileSize,
                            Delete    => $Delete,
                            Location  => $Self->{Location},
                            Css       => $Css,
                        },
                    );
                }
            }
        }
    }

    # show rw options
    if ( $Param{CreateAccessMap} ) {
        $Self->{LayoutObject}->Block(
            Name => 'RwOptions',
            Data => {
                Location => $Self->{Location},
                NewDir   => $Self->{NewDir},
                }
        );
    }

    # browse the tree
    my $Output = $Self->{LayoutObject}->Header( Title => 'File Download' );
    $Output .= $Self->{LayoutObject}->NavigationBar();
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentFileManager',
        Data         => {
            %Param,
            Location => $Self->{Location},
        },
    );
    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

1;
