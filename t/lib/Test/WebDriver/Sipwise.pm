package Test::WebDriver::Sipwise;
use Sipwise::Base;
extends 'Test::WebDriver';

method find(Str $scheme, Str $query) {
    $self->find_element($query, $scheme);
}

method findclick(Str $scheme, Str $query) {
    my $elem = $self->find($scheme, $query);
    return 0 unless $elem;
    return 0 unless $elem->is_displayed;
    $elem->click;
    return 1;
}

method select_if_unselected(Str $scheme, Str $query) {
    my $elem = $self->find($scheme, $query);
    return 0 unless $elem;
    return 0 unless $elem->is_displayed;
    if (! $elem->is_selected() ) {
        $elem->click;
    }
    return 1;
}

method findtext(Str $text, Any $ignore) {
    return $self->find(xpath => "//*[contains(text(),\"$text\")]");
}

method save_screenshot(Str $filename="screenshot.png") {
    use MIME::Base64;
    if($self->get_capabilities->{takesScreenshot}) {
        local *FH;
        open(FH,'>',$filename);
        binmode FH;
        my $png_base64 = $self->screenshot();
        print FH decode_base64($png_base64);
        close FH;
    }
}

method fill_element(ArrayRef $options, Any $ignore) {
    my ($scheme, $query, $filltext) = @$options;
    my $elem = $self->find($scheme => $query);
    return 0 unless $elem;
    return 0 unless $elem->is_displayed;
    $elem->clear;
    $elem->send_keys($filltext);
    return 1;
}

sub browser_name_in {
    my ($self, @names) = @_;
    my $browser_name = $self->get_capabilities->{browserName};
    return $browser_name ~~ @names;
}

#taken from Selenium::Remote::Driver's wiki page
method wait_for_page_to_load (Int $timeout=10000) {
    my $ret = 0;
    my $sleeptime = 2000;  # milliseconds
    my $script_ret = "";

    do {
        sleep ($sleeptime/1000);      # Sleep for the given sleeptime
        $timeout = $timeout - $sleeptime;
        $script_ret = $self->execute_script("return document.readyState");
    } while (($script_ret ne 'complete') && ($timeout > 0));
    if ($script_ret eq 'complete') {
         $ret = 1;
    }
    return $ret;
}

method wait_and_screenshot(Str $filename="screenshot.png") {
    if($self->get_capabilities->{takesScreenshot}) {
        $self->wait_for_page_to_load;
        $self->save_screenshot($filename);
    }
}

