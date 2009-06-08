#!/usr/bin/perl -w

use strict;
use warnings;

my $svn = "svn";
my $svnok = 0;
my $svnq = "$svn -q";
my $tmpdir = exists($ENV{TMP}) ? $ENV{TMP} : "/tmp";

my $svn_rep = $ENV{'SVN_REP'};
my $svn_proj = $ENV{'SVN_PROJ'};
my $work_dir = $ENV{'WORK_DIR'};


sub chkout;
sub chkin;

sub mkfile;
sub mkvdir;
sub mvelem;
sub rmelem;

sub mkenh;
sub mkfix;

sub sshot;
sub udate;

sub mkproj;
sub mkver;
sub lstr;

my %svcmds = (
    'svco' => \&chkout,
    'svci' => \&chkin,
    
    'svmf' => \&mkfile,
    'svmd' => \&mkvdir,
    'svmv' => \&mvelem,
    'svrm' => \&rmelem,
    
    'sv_mkenh' => \&mkenh,
    'sv_mkfix' => \&mkfix,
    'sv_rework' => \&rework,
    
    'svss' => \&sshot,
    'sv_update' => \&udate,
    
    'sva_mkproj' => \&mkproj,
    'sva_mkver' => \&mkver,
    'sva_lstr' => \&lstr
    );

(@ARGV && exists($svcmds{$ARGV[0]}))
    or die "A valid command must be provided, stopped";

my $cmd = shift @ARGV;

chomp @ARGV;

my $verbose = shift @ARGV;

if (defined($verbose)) {
    if ($verbose ne '-v') {
        unshift @ARGV, $verbose;
        undef $verbose;
    } else {
        print "\$SVN_REP=$svn_rep, \$SVN_PROJ=$svn_proj, \$WORK_DIR=$work_dir\n";
    }
}

die "You should have run sv_init_PROJ before this command, stopped"
    unless ($cmd =~ /^sva_/ || ($svn_rep && $svn_proj && $work_dir));

&{$svcmds{$cmd}}($cmd . ' [-v]', @ARGV);


##################################

sub trimmed {
    my $str = (@_ ? shift : $_);
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}


sub abspath {
    my $path = (@_ ? shift : $_);

    if ($path =~ /^(~[^\/]*)/) {
	my $home = `echo $1`;
	chomp $home;
	$path =~ s/^~[^\/]*/$home/;
    }
    my $cwd = `echo \$PWD`;
    chomp $cwd;
    $path = "$cwd/$path" if $path !~ /^\//;
    while($path =~ /\/\.\.?\//) {
	$path =~ s/\/\.\//\//;
	$path =~ s/\/[^\/]*\/\.\.\//\//;
    }
    $path =~ s/\/\.$//;
    $path =~ s/\/[^\/]*\/\.\.$//;

    return $path;
}


sub homeit
{
    my $unhomed = abspath shift;
    my $myhome = `echo ~`;
    chomp $myhome;

    $unhomed =~ s/^\Q$myhome\E(\/|$)/~$1/;

    return $unhomed;
}


sub getsetting
{
    my $set_val = shift;
    my $set_desc = shift;

    print $set_desc;
    print " [$set_val]" if $set_val;
    print ": ";
    $_ = <STDIN>;
    chomp if defined;
    $set_val = $_ if $_;
    $set_val or die 'Please provide ' . ($set_desc ? $set_desc : 'input')
        . ', stopped';
}


sub projpath {
    my $path = (@_ ? shift : $_);

    my $elempath = abspath($path);
    my $workproj = abspath("$work_dir/$svn_proj");

    return '' if $elempath !~ /^$workproj\//;

    return "$'";
}


sub svninfo($)
{
    my $elem = shift;
    my $hr_simap;

    if (defined($verbose)) {
        print "\n\$$svn info $elem\n";
    }
    my @info = `$svn info $elem`;
    if (defined($verbose)) {
        print "@info";
    }
    
    foreach (@info) {
	chomp;
	@_ = split(/:/, $_, 2);
	$hr_simap->{trimmed($_[0])} = trimmed($_[1])
	    if $#_ > 0;
    }

    return $hr_simap;
}


sub svnelems
{
    my @elems;
    foreach my $elem (@_) {
	(push(@elems, projpath($elem)))
	    or die "You are supposed to work with files belonging to the $svn_proj project, stopped";
    }

    return @elems;
}


sub getcomment
{
    my $comment = '';
    print "Please provide description (a single-dot line terminates):\n";
    while (<STDIN>) {
	last if /^\.$/m;
	$comment .= $_;
    }
    chomp $comment;

    return $comment;
}


sub runsvnq
{
    my $cmd = shift;
    my $err = @_ ? shift : 'Problem with repository access';

    if (defined($verbose)) {
        print "\n\$$svn $cmd\n";
        system("$svn $cmd") == $svnok
            or die "\n!\n$err! Stopped";
    } else {
        system("$svnq $cmd 2> /dev/null > /dev/null") == $svnok
            or die "\n!\n$err! Stopped";
    }
}

sub runsvnqcmt
{
    my $cmd = shift;
    my $cmt = @_ ? shift : '';
    my $err = @_ ? shift : 'Problem with repository write-access';

    $cmt =~ s/\'/\\\'/g;

    runsvnq("-m '$cmt' " . $cmd, $err);
}

##################################

sub mkinit
{
    my $sv_init = shift;
    my $new_proj = shift;
    my $svnutil_work_dir = shift;
    my $svnutil_dir = shift;
    my $unver_dirs = shift;
    
    print $sv_init "\nif ( ! \$?SVN_UTIL ) setenv SVN_UTIL $svnutil_work_dir\n";
    print $sv_init "if ( ! \$?SVN ) set SVN=\"$svn\"\n";
    print $sv_init "setenv SVN_REP $svn_rep\n";
    print $sv_init "setenv SVN_PROJ $new_proj\n";
    print $sv_init "setenv WORK_DIR $work_dir\n";
    print $sv_init "\nif ( ! -e \$SVN_UTIL ) then\n";
    if ($svnutil_dir eq '-') {
	print $sv_init "  echo \"No svnutil at \$SVN_UTIL. Please install it manually or something!\"\n";
	print $sv_init "  exit -1\n";
    } else {
	print $sv_init "  echo \"No svnutil at \$SVN_UTIL. Will try to install..\"\n";
	print $sv_init "  if ( ! -w \$SVN_UTIL:h ) then\n";
	print $sv_init "    echo \"Cannot install (not writable parent directory)!\"\n";
	print $sv_init "    exit -1\n";
	print $sv_init "  endif\n";
	print $sv_init "  if ( ! { \$SVN -q co \$SVN_REP/svnutil \$SVN_UTIL } ) then\n";
	print $sv_init "    echo \"Cannot install (failed to fetch from \$SVN_REP/svnutil)!\"\n";
	print $sv_init "    exit -1\n";
	print $sv_init "  endif\n";
    }
    print $sv_init "endif\n";
    print $sv_init "set new_proj=0\n";
    print $sv_init "\nif ( ! -e \$WORK_DIR/\$SVN_PROJ ) then\n";
    print $sv_init "  echo \"Hey, this is a new project. Good luck..\"\n";
    print $sv_init "  set new_proj=1\n";
    print $sv_init "  if ( ! { mkdir \$WORK_DIR/\$SVN_PROJ } ) then\n";
    print $sv_init "    echo \"Cannot create the project work directory (not writable parent directory)!\"\n";
    print $sv_init "    exit -1\n";
    print $sv_init "  endif\n";
    foreach (split(' ', $unver_dirs)) {
	print $sv_init "  if ( ! { \$SVN -q co \$SVN_REP/\$SVN_PROJ/$_ \$WORK_DIR/\$SVN_PROJ/$_ } ) then\n";
	print $sv_init "    echo \"Cannot fetch $_ from \$SVN_REP/\$SVN_PROJ/$_!\"\n";
	print $sv_init "    exit -1\n";
	print $sv_init "  endif\n";
    }
    print $sv_init "endif\n";
    print $sv_init "\nsource \$SVN_UTIL/sv_init.csh\n";
    print $sv_init "\nif ( \$new_proj ) then\n";
    print $sv_init "  echo \"You are welcome to start developing right away, but not before you create your first working branch here by running sv_mkenh or sv_mkfix.\"\n";
    print $sv_init "else\n";
    print $sv_init "  source \$SVN_UTIL/sv_branch.csh\n";
    print $sv_init "endif\n";
    print $sv_init "\nif ( -rf build.env ) then\n";
    print $sv_init "  source build.env\n";
    print $sv_init "else\n";
    print $sv_init "  if ( \$new_proj ) echo \"Note that you can place additional build environment initialization in ./build.env that will then be automatically sourced in the end of this script.\"\n";
    print $sv_init "endif\n";
}


sub mkwork
{
    my $mkre = shift;
    my $enhfix;
    $enhfix = shift if $mkre;
    my $branch_name = shift;
    my $version = shift;

    die "The branch name has to be an identifier-like word, stopped"
	if ($branch_name !~ /^[[:alpha:]]\w*$/);

    my $workbranch;
    if ($mkre) {
        (my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday,
         my $yday, my $isdst) = gmtime(time);
        my $date = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);

        $workbranch = ($enhfix ? 'e' : 'f') . "_${date}_$branch_name";
    } else {
        $workbranch = $branch_name;
        $enhfix = $workbranch =~ /^e_/;
    }

    die "Something already exists at $work_dir/$svn_proj/$workbranch, stopped"
	if (-e "$work_dir/$svn_proj/$workbranch");

    my $majver;
    my $minver;

    if (defined($version)) {
	die "Invalid base version, stopped"
	    if ($version !~ /^(\d+)(\.(\d+))?$/);
	$majver = $1;
	$minver = $3;
    }

    if (defined($majver)) {
	die "The specified major version doesn't exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$majver/ 2> /dev/null > /dev/null") != $svnok);
    } else {
        print "No version has been specified, assuming..";
	$majver = `$svn ls $svn_rep/$svn_proj/_/ | grep -v _ | cut -f1 -d/ | tail -n 1`;
	chomp $majver;
        print "..$majver";
    }

    if (defined($minver)) {
	die "You cannot enhance a minor version, only fix it, stopped"
	    if ($enhfix);
	die "The specified minor version doesn't exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$majver/$minver/ 2> /dev/null > /dev/null") != $svnok);
    } elsif (!$enhfix) {
        print "No minor version has been specified, assuming....$majver"
            if defined($version);
	$minver = `$svn ls $svn_rep/$svn_proj/_/$majver/ | grep -v _ | cut -f1 -d/ | tail -n 1`;
        chomp $minver;
        print ".$minver\n";
    } else {
        print "\n" if !defined($version);  # For the major version assumption.
    }

    my $verdir = $majver;
    $verdir .= '/' . $minver
	unless $enhfix;

    if ($mkre) {
        print "Checking the integrity of the $verdir branch..";
        my $base_rev1 = `$svn log -q --incremental --limit 1 $svn_rep/$svn_proj/_/$verdir/_ | tail -n 1 | cut -c2- | cut -d' ' -f1`;
        chomp $base_rev1;
        my $base_rev2 = `$svn --strict propget base_rev $svn_rep/$svn_proj/_/$verdir/_`;
        chomp $base_rev2;

        $base_rev1 == $base_rev2
            or die "..FAILED!\nReport this to The Administrator at once!\nStopped";
        print "..success\n";

        my $comment = getcomment;
        print "Branching from the $verdir branch..";
        runsvnqcmt("mkdir $svn_rep/$svn_proj/_/$verdir/$workbranch", $comment);
        runsvnqcmt("cp $svn_rep/$svn_proj/_/$verdir/_ $svn_rep/$svn_proj/_/$verdir/$workbranch/_");
        print "..done\n";
    }

    print "Checking out the working branch..";
    runsvnq("co $svn_rep/$svn_proj/_/$verdir/$workbranch/_ $work_dir/$svn_proj/$workbranch");
    print "..done\n";

#    my $base_rev = `svnversion $work_dir/$svn_proj/$workbranch`;
#    chomp $base_rev;
#    system("$svn -q propset base_rev $base_rev $work_dir/$svn_proj/$workbranch") == $svnok
#	or die "Failed to set the base revision property, stopped";

    print "\nThat's it. You've got your working branch copy at $work_dir/$svn_proj/$workbranch\n";
    print "Hint: source sv_init_$svn_proj again to start working on it. Good luck!\n";
}


#########################################

sub mkproj
{
    my $cmd = shift;
    my $new_proj = shift;
    die "usage:\t$cmd new_project\n\t..stopped"
	if (!defined($new_proj) || @_);

    print "\nYou are about to create a new project named $new_proj!\n\n";
    print "\nNote that you may be asked for your credentials...\n";

    $svn_rep = getsetting($svn_rep ? $svn_rep : '', "repository url");
    die "Hey, that's not a valid url, stopped"
	if ($svn_rep !~ /^https?:\/\//);
    runsvnq("log $svn_rep", "The repository cannot be accessed at $svn_rep");
    die "A project with this name already exists (or something at $svn_rep/$new_proj at least), stopped"
	if (system("$svn ls $svn_rep/$new_proj/ 2> /dev/null > /dev/null") == $svnok);

    $work_dir = getsetting($work_dir ? homeit($work_dir) : "~/work",
			   "developer's work directory");
    die "A project with this name already exists (or something at $work_dir/$new_proj at least), stopped"
	if (-e abspath("$work_dir/$new_proj"));


    my $svnutil_dir;
    if (system("$svn ls $svn_rep/svnutil/ 2> /dev/null > /dev/null") == $svnok) {
	$svnutil_dir = '+';
	print "svnutil exists in $svn_rep, please update it manually if needed\n";
    } else {
	print "The svnutil will be installed into the repository if desired\n";
	$svnutil_dir = getsetting(exists($ENV{SVN_UTIL}) ? $ENV{SVN_UTIL} :
				  "$work_dir/svnutil",
				  "svnutil source directory ('-' for don't install)");
	(-d abspath($svnutil_dir) && -r abspath($svnutil_dir))
	    or die "\n!\n The svnutil directory is not valid. Stopped"
	    if $svnutil_dir ne '-';
    }


    my $svnutil_work_dir = getsetting($svnutil_dir !~ /^[+-]$/ ? $svnutil_dir :
				      (exists($ENV{SVN_UTIL}) ?
				       homeit($ENV{SVN_UTIL}) : "$work_dir/svnutil"),
				      "developer's svnutil directory");


    my $unver_dirs = getsetting("doc rel",
				"unversioned project directories ('-' for none)");
    $unver_dirs = '' if $unver_dirs eq '-';



    print "Thus, do you want to create the $new_proj project";
    print " in the $svn_rep repository";
    print " with some unversioned directories ($unver_dirs)" if $unver_dirs;
    print " {yes?}:";
    die "As you wish, stopped"
	unless <STDIN> =~ /^YES$/i;


    if ($svnutil_dir ne '+' && $svnutil_dir ne '-') {
	print "Exporting the svnutil..";
	runsvnqcmt("import $svnutil_dir $svn_rep/svnutil");
	print "..done\n";
    } 

    print "Making the project and its main branch directories..";
    runsvnqcmt("mkdir $svn_rep/$new_proj");
    runsvnqcmt("mkdir $svn_rep/$new_proj/_");
    runsvnqcmt("mkdir $svn_rep/$new_proj/_/_");
    print "..done\n";

    print "Making the unversioned directories..";
    foreach (split(' ', $unver_dirs)) {
	print "$_..";
	runsvnqcmt("mkdir $svn_rep/$new_proj/$_");
    }
    print "..done\n";
    
    
    print "Creating the sv_init_$new_proj script..";

    open(my $sv_init, '>', "$tmpdir/sv_init_$new_proj")
	or die "\n!\nProblem writing to $tmpdir/sv_init_$new_proj, stopped";
    mkinit($sv_init, $new_proj, $svnutil_work_dir, $svnutil_dir, $unver_dirs);
    close $sv_init;
	
    runsvnqcmt("import $tmpdir/sv_init_$new_proj $svn_rep/$new_proj/sv_init_$new_proj");
    unlink "$tmpdir/sv_init_$new_proj";

    print "..done\n";

    print "\nThe $new_proj project has been successfully created.\n";
    print "Hint: svn cat $svn_rep/$new_proj/sv_init_$new_proj > $work_dir/sv_init_$new_proj\n";
    print " Then source $work_dir/sv_init_$new_proj in tcsh every time before developer work.\n";
}


sub mkver
{
    my $cmd = shift;
    my $svn_proj = shift;
    my $version = shift;
    my $workbranch = shift;

    die "usage:\t$cmd project {X.Y|X.Y.Z} [work_branch]\n\t..stopped"
	if (!defined($version) || $version !~ /^\d+\.\d+(\.\d+)?$/);

    $svn_rep = getsetting($svn_rep ? $svn_rep : '', "repository url");
    die "Hey, that's not a valid url, stopped"
	if ($svn_rep !~ /^https?:\/\//);

    my @base_ver = split(/\./, $version);
    my $new_ver = pop @base_ver;
    
    my $baseverdir = join('/', @base_ver);

    die "The project version branch $svn_proj/$baseverdir does not exist at $svn_rep, stopped"
	if (system("$svn ls $svn_rep/$svn_proj/_/$baseverdir/_/ 2> /dev/null > /dev/null") != $svnok);

    my $base_rev = `$svn log -q --incremental --limit 1 $svn_rep/$svn_proj/_/$baseverdir/_ | tail -n 1 | cut -c2- | cut -d' ' -f1`;
    chomp $base_rev;

    die "The version branch $baseverdir/$new_ver already exists, stopped"
	if (system("$svn ls $svn_rep/$svn_proj/_/$baseverdir/$new_ver/ 2> /dev/null > /dev/null") == $svnok);

    if (defined($workbranch)) {
	die "The working branch $workbranch does not exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$baseverdir/$workbranch/_/ 2> /dev/null > /dev/null") != $svnok);

        print "Checking if the working branch is updated..";
        my $work_base_rev = `$svn --strict propget base_rev $svn_rep/$svn_proj/_/$baseverdir/$workbranch/_`;
        chomp $work_base_rev;
        $base_rev == $work_base_rev
            or die "..FAILED! Please update it before re-running this command!\nStopped";
        print "..success\n";

	$work_dir = getsetting($work_dir ? homeit($work_dir) : "~/work",
			       "work directory");

	$work_dir = abspath($work_dir);

	mkdir $work_dir;
	mkdir "$work_dir/$svn_proj";
	
	my $integdir = 'i_' . join('_', @base_ver);
	
        print "NOTE: If there are any errors, the integ. dir. has to be removed manually\n\t(Hint: \\rm -Rf $work_dir/$svn_proj/$integdir)\n";
        print "NOTE2: If the merge succeeds, DO NOT forget to\n\tsv_update the $workbranch BEFORE continuing working on it\n";

	die "Cannot use $work_dir/$svn_proj/$integdir for the integration, stopped"
	    if (!-d "$work_dir/$svn_proj" || !-w "$work_dir/$svn_proj" || -e "$work_dir/$svn_proj/$integdir");
	
	print "Checking out the base version branch..";
	runsvnq("co $svn_rep/$svn_proj/_/$baseverdir/_ $work_dir/$svn_proj/$integdir",
                "Cannot use actually checkout the base version branch");
	print "..done\n";
	
	my $dummy;
	my $svnstat;
	
        print "Merging in the $workbranch workbranch..";
        runsvnq("merge $svn_rep/$svn_proj/_/$baseverdir/_ $svn_rep/$svn_proj/_/$baseverdir/$workbranch/_ $work_dir/$svn_proj/$integdir",
                "Failed to actually merge $workbranch");
        
        print "..checking for any (unexpected) conflicts..";
        print "\n\$$svnq status $work_dir/$svn_proj/$integdir | cut -c 1-8 | grep -F C [output suppressed]\n"
            if defined($verbose);
        open($svnstat, "$svnq status $work_dir/$svn_proj/$integdir | cut -c 1-8 | grep -F C |") or
            die "Problem with the working copy, stopped";
        $dummy = <$svnstat>;
        die "\nThere are merge conflicts, which should be resolved in the working branches, stopped"
            if ($dummy);
        print "..none..";
        
	my $hr_elem_info = svninfo("$svn_rep/$svn_proj/_/$baseverdir/_");
        my $new_base_rev = $hr_elem_info->{'Revision'};
        chomp $new_base_rev;
        $new_base_rev++;
	runsvnq("propset base_rev $new_base_rev $work_dir/$svn_proj/$integdir",
                "Failed to set the base revision property");
        print "..done\n";

#	print "\nIt is recommended that you review the merge(s) and checkin the integration branch manually!\n";
#	print "Do you want to continue and checkin the $baseverdir automatically?";
#	die "As you wish,\nHint: \\$svn -m'Merged $workbranch towards $version' ci $work_dir/$svn_proj/$integdir\n\\rm -Rf $work_dir/$svn_proj/$integdir\nstopped"
#	    unless getsetting('yes', '') =~ /^YES$/i;
	
	print "Checking in the base version branch..";
	runsvnqcmt("ci $work_dir/$svn_proj/$integdir",
                   "Merged $workbranch towards $version",
                   "Cannot use actually checkout the base version branch");
	print "..done\n";

	print "Cleaning up..";
	die "Cannot remove the integration directory, please remove it manually, stopped"
	    if system("\\rm -Rf $work_dir/$svn_proj/$integdir");
	print "..done\n";
    }

    print "Thus, do you want to create the $svn_proj/$version version branch";
    print " from its base branch? {yes?}:";
    die "As you wish, stopped"
	unless <STDIN> =~ /^YES$/i;

    print "Branching from the $baseverdir branch..";
    runsvnqcmt("mkdir $svn_rep/$svn_proj/_/$baseverdir/$new_ver");
    runsvnqcmt("cp $svn_rep/$svn_proj/_/$baseverdir/_ $svn_rep/$svn_proj/_/$baseverdir/$new_ver/_");
    print "..done\n";
}


sub mkfile
{
    my $cmd = shift;

    die "usage:\t$cmd [new_file ...]\n\t..stopped"
        unless @_;

    my @elems = svnelems(@_);

    foreach my $elem (@elems) {
	die "$elem is a directory (use svmd), stopped"
	    unless (! -e "$work_dir/$svn_proj/$elem" ||
		    -f "$work_dir/$svn_proj/$elem");
	system("touch $work_dir/$svn_proj/$elem") == 0 or
	    die "Cannot touch $work_dir/$svn_proj/$elem, stopped";
	runsvnq("add $work_dir/$svn_proj/$elem",
                "Failed to actually add $elem");
    }
}


sub mkvdir
{
    my $cmd = shift;

    # no usage here, sorry

    my @elems = svnelems(@_ ? @_ : '.');

    foreach my $elem (@elems) {
	die "$elem is a file (use svmf), stopped"
	    unless (! -e "$work_dir/$svn_proj/$elem" ||
		    -d "$work_dir/$svn_proj/$elem");
	die "'_' is a reserved directory name, stopped"
	    if ($elem =~ /.*\/_$/);
	mkdir "$work_dir/$svn_proj/$elem";
	system("touch $work_dir/$svn_proj/$elem") == 0 or
	    die "Cannot touch $work_dir/$svn_proj/$elem, stopped";
	runsvnq("-N add $work_dir/$svn_proj/$elem",
                "Failed to actually add $elem");
    }
}


sub mvelem
{
    my $cmd = shift;

    die "usage:\t$cmd source ... [target:.]\n\t..stopped"
        unless @_;

    push(@_, '.') if ($#_ < 1);
    my @elems = svnelems(@_);
    my $dst = pop @elems;

    die "You cannot move multiple files into one, stopped"
	if ($#elems > 0 && ! -d "$work_dir/$svn_proj/$dst");

    foreach my $elem (@elems) {
	runsvnq("mv $work_dir/$svn_proj/$elem $work_dir/$svn_proj/$dst",
                "Failed to actually move $elem, stopped");
    }
}


sub rmelem
{
    my $cmd = shift;

    die "usage:\t$cmd source ... [target:.]\n\t..stopped"
        unless @_;

    my @elems = svnelems(@_);

    foreach my $elem (@elems) {
	runsvnq("rm $work_dir/$svn_proj/$elem",
                "Failed to actually remove $elem");
    }
}


sub chkout
{
    my $cmd = shift;

    # no usage here, sorry

    my @elems = svnelems(@_ ? @_ : '.');

    foreach my $elem (@elems) {
	die "$elem should be an existing directory, stopped"
	    unless (-d abspath("$work_dir/$svn_proj/$elem"));

	my $hr_elem_info = svninfo("$work_dir/$svn_proj/$elem");
	my $url = $hr_elem_info->{'URL'};
	die "$elem is not under source control (checkout its parent dir?), stopped"
	    unless (defined $url);
	die "$elem is versioned, please use applicable commands, stopped"
	    if ($url =~ /\/_\//);

	runsvnq("co $svn_rep/$svn_proj/$elem $work_dir/$svn_proj/$elem",
                "Failed to actually checkout $elem");
    }
}


sub chkin
{
    my $cmd = shift;
    
    # no usage here, sorry

    my @elems = svnelems(@_ ? @_ : '.');

    foreach my $elem (@elems) {
	my $hr_elem_info = svninfo("$work_dir/$svn_proj/$elem");
	my $url = $hr_elem_info->{'URL'};
	die "$elem is not under source control, stopped"
	    unless (defined $url);
	die "$elem is versioned, please use applicable commands, stopped"
	    if ($url =~ /\/_\//);

	runsvnqcmt("ci $work_dir/$svn_proj/$elem", getcomment,
                   "Failed to actually checkin $elem");
    }
}


sub mkenh
{
    my $cmd = shift;
    my $short_name = shift;
    my $version = shift;

    die "usage:\t$cmd new_work_branch_short_name [X:LAST]\n\t..stopped"
	if (!defined($short_name) || @_);

    mkwork(1, 1, $short_name, $version);
}


sub mkfix
{
    my $cmd = shift;
    my $short_name = shift;
    my $version = shift;

    die "usage:\t$cmd new_work_branch_short_name [X.Y:LAST.LAST]\n\t..stopped"
	if (!defined($short_name) || @_);

    mkwork(1, 0, $short_name, $version);
}


sub rework
{
    my $cmd = shift;
    my $workbranch = shift;
    my $version = shift;

    die "usage:\t$cmd work_branch [X:LAST[.Y:LAST]]\n\t$cmd {X:LAST|X.Y:LAST.LAST}\n\t..stopped"
	if (!defined($workbranch));

    if ($workbranch =~ /^(\d+)(\.(\d+))?$/) {
        my $verdir = $1;
        $verdir .= '/' . $3
            if defined($3);

	die "The specified version doesn't exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$verdir/ 2> /dev/null > /dev/null") != $svnok);

        print `$svn ls $svn_rep/$svn_proj/_/$verdir/ | grep -E '^[ef]_' | cut -d/ -f1`;
    } else {
        mkwork(0, $workbranch, $version);
    }
}


sub sshot
{
    my $cmd = shift;
    
    # no usage here, sorry

    my @elems = svnelems(@_ ? @_ : '.');

    foreach my $elem (@elems) {
	my $hr_elem_info = svninfo("$work_dir/$svn_proj/$elem");
	my $url = $hr_elem_info->{'URL'};
	die "$elem is not under source control, stopped"
	    unless (defined $url);
	die "$elem is not a working copy of this project branch, stopped"
	    unless ($url =~ m/^\Q$svn_rep\E\/\Q$svn_proj\E\/_\/\d+(\/\d+)?\/[^\/]+\/_$/);
        print "\n\$$svn status $work_dir/$svn_proj/$elem\n"
            if defined($verbose);

	open(my $svnstat, "$svn status $work_dir/$svn_proj/$elem |") or
	    die "Cannot access the project's repository, stopped";
	my $status = 0;
        while (<$svnstat>) {
            print;
            $status = 2 if (/\?/);
            $status = 1 if (!$status);
        }
	if ($status) {
            print "\n";
            print "WARNING: There are unrevisioned files (marked with ?)!\n"
                if $status == 2;
            print "Go on with the snapshot? {yes?}";
            die "As you wish, stopped"
                unless getsetting($status == 2 ? '' : 'yes', '') =~ /^YES$/i;

            my $comment = getcomment;

            print "Committing the working copy..";

            print "..updating it first..";

            print "\n\$$svn update $work_dir/$svn_proj/$elem | grep -vF 'At revision'\n"
                if defined($verbose);
            
            my $updated = `$svn update $work_dir/$svn_proj/$elem`;

            print "\n$updated\n" if defined($verbose);

            die "\nERROR: Your working copy was not updated. It IS now:\n$updated\nPlease run this command again after reviewing the update performed, stopped"
                if ($updated !~ /^At revision \d+.$/);

            print "..ok..";

	    runsvnqcmt("ci $work_dir/$svn_proj/$elem", $comment,
                       "Failed to actually checkin $elem");
            print "..done\n";
	} else {
	    print "$elem is not changed, nothing to do, skipping..\n";
	}
    }
}


sub udate
{
    my $cmd = shift;
    
    # no usage here, sorry

    my @elems = svnelems(@_ ? @_ : '.');

    foreach my $elem (@elems) {
	my $hr_elem_info = svninfo("$work_dir/$svn_proj/$elem");
	my $url = $hr_elem_info->{'URL'};
	die "$elem is not under source control, stopped"
	    unless (defined $url);
	die "$elem is not a working copy of this project branch, stopped"
	    unless ($url =~ m/^\Q$svn_rep\E\/\Q$svn_proj\E\/_\/(\d+(\/\d+)?)\/[^\/]+\/_$/);
	my $verdir = $1;

        print "\n\$$svnq status $work_dir/$svn_proj/$elem [output suppressed]\n"
            if defined($verbose);
	open(my $svnstat, "$svnq status $work_dir/$svn_proj/$elem |")
	    or die "Cannot access the project's repository, stopped";
	my $dummy = <$svnstat>;
        die "Please snapshot the working copy first (svss), as it has changes, stopped"
            if ($dummy);
	
        print "\n\$$svn status $work_dir/$svn_proj/$elem\n"
            if defined($verbose);
	open(my $svnstat2, "$svn status $work_dir/$svn_proj/$elem |")
	    or die "Cannot access the project's repository, stopped";
        my $status = 0;
        while (<$svnstat2>) {
            print;
            $status = 1;
        }
        if ($status) {
            print "WARNING: There are unrevisioned files (shown above). Go on with the update? {yes?}:";
            die "As you wish, stopped"
                unless <STDIN> =~ /^YES$/i;
        }
	
        print "Checking the integrity of the $verdir branch..";
        my $base_rev = `$svn log -q --incremental --limit 1 $svn_rep/$svn_proj/_/$verdir/_ | tail -n 1 | cut -c2- | cut -d' ' -f1`;
        chomp $base_rev;
        my $base_rev2 = `$svn --strict propget base_rev $svn_rep/$svn_proj/_/$verdir/_`;
        chomp $base_rev2;

        $base_rev == $base_rev2
            or die "..FAILED! Report this to The Administrator at once!\nStopped";
        print "..success\n";

	my $prev_base_rev = `$svn --strict propget base_rev $work_dir/$svn_proj/$elem`;
	chomp $prev_base_rev;

	die "Your working branch is already at the latest revision, stopped"
	    if $base_rev == $prev_base_rev;

	runsvnq("-r $prev_base_rev:$base_rev merge $svn_rep/$svn_proj/_/$verdir/_ $work_dir/$svn_proj/$elem",
                "Failed to actually merge $elem from $verdir, stopped");

        print "\n\$$svnq status $work_dir/$svn_proj/$elem | cut -c 1-8 | grep -F C | [output suppressed]\n"
            if defined($verbose);
	open($svnstat, "$svnq status $work_dir/$svn_proj/$elem | cut -c 1-8 | grep -F C |") or
	    die "Cannot access the project's repository, stopped";
	$dummy = <$svnstat>;
	print "Note that you have merge conflicts here!\n" if ($dummy);
    }

    print "You are kindly advised to snapshot the working copy after reviewing the update.\n";
}

sub lstr
{
    my $cmd = shift;
    my $version = shift;

#    die "usage:\t$cmd [X:LAST|X.Y]\n\t..stopped"
#	if (!defined($version) || @_);

    my $majver;
    my $minver;

    if (defined($version)) {
        #TODO(low) is this check needed?
	die "Invalid version, stopped"
	    if ($version !~ /^(\d+)(\.(\d+))?$/);
	$majver = $1;
	$minver = $3;
    }

    if (defined($majver)) {
	die "The specified major version doesn't exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$majver/ 2> /dev/null > /dev/null") != $svnok);
    } else {
        print "No version has been specified, assuming..";
	$majver = `$svn ls $svn_rep/$svn_proj/_/ | grep -v _ | cut -f1 -d/ | tail -n 1`;
	chomp $majver;
        print "..$majver\n";
    }

    my $verdir = $majver;

    if (defined($minver)) {
	die "The specified minor version doesn't exist, stopped"
	    if (system("$svn ls $svn_rep/$svn_proj/_/$majver/$minver/ 2> /dev/null > /dev/null") != $svnok);
        $verdir .= '/' . $minver;
    }


    my @branches = `$svn ls $svn_rep/$svn_proj/_/$verdir | grep -E '^[ef]_' | cut -d/ -f1`;
    if (defined($verbose)) {
        print "\$$svn ls $svn_rep/$svn_proj/_/$verdir | grep -E '^[ef]_' | cut -d/ -f1\n";
        print "@branches"
    }
    
    my @merge_revs = `$svn log --incremental $svn_rep/$svn_proj/_/$verdir | grep -E -C2 '^Merged '`;
    
    foreach my $branch (@branches) {
        my $merge_flag = ' ';

        #TODO(low) implement the propagation flag for minor version branches
        my $prop_flag = ' ';

        my $merge_date;
        my $merge_dev;
        my $merge_rev;

	chomp $branch;
        my $branch_rev_t = `$svn log -q --incremental --limit 1 $svn_rep/$svn_proj/_/$verdir/$branch | tail -n 1`;
	die "SVN compatibility problem, stopped"
            if (!defined($branch_rev_t) || $branch_rev_t !~ /^r(\d+) \| (\S+) \| (\S+)/);
        my $branch_rev = $1;
        $merge_dev = $2;
        $merge_date = $3;

        my $merge_rev_t;
        for (my $i = 0; $i <= $#merge_revs; $i++) {
            if ($merge_revs[$i] =~ /^Merged $branch/) {
                $merge_rev_t = $merge_revs[$i-2];
                last;
            }
        }
        if (!defined($merge_rev_t)) {
            $merge_flag = 'N';
        } else {
            die "SVN compatibility problem, stopped"
                if ($merge_rev_t !~ /^r(\d+) \| (\S+) \| (\S+)/);
            $merge_rev = $1;
            $merge_dev = $2;
            $merge_date = $3;

            if ($merge_rev > $branch_rev) {
                $merge_flag = 'G';
            } else {
                $merge_flag = 'U';
            }
        }
        print "${merge_flag}${prop_flag}  ${merge_date}  $branch ($merge_dev"
            . (defined($merge_rev) ? ", r$merge_rev" : '') . ")\n";
    }
}
