package NGCP::Panel::Field::DataTable;
use Moose;
use Template;
extends 'HTML::FormHandler::Field';

has 'template' => ( isa => 'Str', is => 'rw' );
has 'ajax_src' => ( isa => 'Str', is => 'rw' );
has 'table_fields' => ( isa => 'ArrayRef', is => 'rw' );

sub render_element {
    my ($self) = @_;
    my $output = '';

    (my $tablename = $self->html_name) =~ s!\.!!g;

    my $vars = {
        checkbox_name => $self->html_name,
        table_id => $tablename . "table",
        value => $self->value,
        ajax_src => $self->ajax_src,
        table_fields => $self->table_fields,
    };
    my $t = new Template({});

    $t->process($self->template, $vars, \$output) || 
        print ">>>>>>>>>>>>>>>>> failed to process tt: ".$t->error()."\n";

    return $output;
}
 
sub render {
    my ( $self, $result ) = @_;
    $result ||= $self->result;
    die "No result for form field '" . $self->full_name . "'. Field may be inactive." unless $result;
    my $output = $self->render_element( $result );
    return $self->wrap_field( $result, $output );
}


1;

# vim: set tabstop=4 expandtab:
