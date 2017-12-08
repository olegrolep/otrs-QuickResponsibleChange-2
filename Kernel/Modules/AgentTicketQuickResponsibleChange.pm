# --
# Kernel/Modules/AgentTicketQuickResponsibleChange.pm - bulk changing responsible of tickets
# Copyright (C) 2015 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketQuickResponsibleChange;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Web::Request',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Ticket',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = { %Param };
    bless($Self, $Type);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my @TicketIDs = $ParamObject->GetArray(Param => 'TicketID');
    my $ID = $ParamObject->GetParam(Param => 'QuickResponsibleChange');
    my $ZoomMarker = $ParamObject->GetParam(Param => 'Zoom');

    # get log object
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if (!@TicketIDs) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    if (!$ID) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No ResponsibleID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my @NoAccess;

    TICKETID:
    for my $TicketID (@TicketIDs) {

        # check permissions
        my $Access = $TicketObject->TicketPermission(
            Type     => 'owner',
            TicketID => $TicketID,
            UserID   => $Self->{UserID}
        );

        # error screen, don't show ticket
        if (!$Access) {
            push @NoAccess, $TicketID;
            next TICKETID;
        }

        $TicketObject->TicketResponsibleSet(
            TicketID  => $TicketID,
            NewUserID => $ID,
            UserID    => $Self->{UserID},
        );

        if ($ConfigObject->Get('QuickResponsibleChange::SetLock')) {
            if ($ID == 1) {
                $TicketObject->TicketLockSet(
                    Lock     => 'unlock',
                    TicketID => $TicketID,
                    UserID   => $Self->{UserID},
                );
            }
            else {
                $TicketObject->TicketLockSet(
                    Lock     => 'lock',
                    TicketID => $TicketID,
                    UserID   => $Self->{UserID},
                );
            }
        }

        if ($ConfigObject->Get('QuickResponsibleChange::BecomeOwner')) {
            $TicketObject->TicketOwnerSet(
                TicketID  => $TicketID,
                NewUserID => $Self->{UserID},
                UserID    => $Self->{UserID},
            );
        }
    }

    # redirect parent window to last screen overview on closed tickets
    if (!@NoAccess) {
        my $LastView = $Self->{RequestedUrl} || $Self->{LastScreenOverview} || $Self->{LastScreenView} || 'Action=AgentDashboard';

        my $OP = $LastView;
        if (@TicketIDs == 1 && $ZoomMarker) {
            $OP = 'Action=AgentTicketZoom&TicketID=' . $TicketIDs[0];
        }

        return $LayoutObject->Redirect(
            OP => $OP,
        );

    }
    else {
        return $LayoutObject->ErrorScreen(
            Message => $LayoutObject->{LanguageObject}->Translate(
                'No access to these tickets (IDs: %s)', join(", ", @NoAccess)),
            Comment => Translatable('Please contact the administrator.'),
        );
    }
}

1;
