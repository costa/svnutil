**THIS IS A SLIGHTLY OUTDATED README OF A GREATLY OUTDATED PROJECT**  
*It did work great for me though, so if you're still into Subversion, you may find it useful or fun.*  
*fun*... right... see the date below, and excuse me for not making it public earlier
***
### Project Versioning

I think the code versions for each project should consist of three numbers separated by dots (wow! what a surprise!) like 3.0.0 or 12.13.14. The first number is for independent architecture variants, the second one is for architecture-compatible major features and "service packs" and the last one is for bug fixes and minor interface-compatible code enhancements. The code version is a "frozen" (built, checked to some extent and probably released) state of a group of objects that can be referred to. This state is stored in a minor branch as described below.

There will be direct correlation with branches:

* / - main branch, merely a "root directory" for major branches. Only a project versioner may manage major branches here (create "scratch", copy-paste, remove obsolete). May contain code of the latest release or something (TBD).
* /x - major branches, root directories for minor branches. A project versioner integrates enhancement branches to such branches, thus they contain the latest code for the corresponding major versions. The code is copied to the enhancement branches to make further development or to minor branches for the production-level testing.
* /x/&lt;workbranch&gt; - enhancement branches. These are owned by developers who actually work on the code.
* /x/x - minor branches, root directories for version branches. A project versioner integrates bug fix branches to such branches, thus they contain the latest code for the corresponding minor versions. The code is copied to the bug fix branches to make further fixes or to version branches for releases.
* /x/x/&lt;workbranch&gt; - bug fix branches. These are owned by developers who actually work on the code.
* /x/x/x - version branches, frozen code containers. These are created by a project versioner upon project version release (after production-level testing and stuff).

The version's lifecycle is as follows:

* development - the version is being created (merges, builds, test etc.).
* maintenance - the version can be "changed" (a subsequent version can be created out of it).
* obsoletion - the version is not needed anymore (usually after a subsequent version is created).

I think that the correlation with branches is clear. So, I won't describe their lifecycle. See note on the releases below.

As may be seen from above, a branch of any level contains the latest code for this branch, i.e. it is always newer or same then any of its sub-branches. For the exotic cases (let's hope and try there won't be any), a change in a branch (either major or minor) can be propagated to a parallel branch. E.g. our latest version is 5.x.x, we have to fix the 4.x.x version and we want to update the 3.x.x version (or vice versa) since they're both in the maintenance state. In this case, it is better to update the earlier version first and then forward-propagate it to the latter one.

#### Notes

* The initial version of the project is '0.1.0' (I don't like the idea of having a triple zero version, let it be the perfect imaginary empty version). Any other versions should be 'x.0.0', 'x.0.1', 'x.2.0' and so on. '0.x.x' versions can be released only as an "alpha" or a "beta".
* A release contains a version from each of the related projects. It can be named after the main project version with addition of 'a' for alpha, 'b' for beta, and other stuff (like "home edition", "enterprise", etc.). The release management should also be put under source control, but independently of the code version. It seems to be a good technique to create a VCS (Version Control System) directory named '/&lt;project&gt;/rel' and then make subdirectories there named after release names (e.g. '/car/rel/4.5.0b'). Release configuration, code version numbers and other stuff will be kept there.
* Other examples of single-branched data are documents, internal or external (cached), as well as certain kinds of multimedia (photographs, for instance).
* The trailing zeroes can be suppressed in releases if we name them after main project versions, of course.

### Subversion Branching

Subversion does not have such things as branches or labels. Instead, it has a nice lazy-copy mechanism. What do we do out of this?

Suppose we want to refer to a branch '3/1/1004\_engine\_fix' (oh, I just love nested branches, timestamped branch name is a good idea as well) of a file '/core/engine/ignition.c' in a project 'car'. The path that will be used in the repository is '/car/\_/3/1/1004\_engine\_fix/\_/core/engine/ignition.c'. That is, the first part of this inter-repository path is the project name, then the branch name and then the "full path" inside the project, all separated by '\_''s.

Thus, the very main branch code files are located at '/&lt;project&gt;/\_/\_/'. Appropriate scripts for all the common source management activities will be supplied. The only limitation of this technique is that you can't name a directory '\_'. Well, you can stand this, right?

### Activities & Automation (svnutil)

The version control activities are traditionally divided into project developer activities and project versioner (a better title for this job, anyone?) activities.

_Notes_:

* Critical automated operations (sv-commands) will require a confirmation from the user. In addition, they are given longer names to prevent accidental execution.
* Optional arguments are shown inside brackets with their defaults separated by a colon ([optional: default]).
* The project versioner will create, update and make accessible a script (named sv\_init\_&lt;project&gt;.[c]sh, in the project's main VCS directory) that has to be called (sourced) by a developer in a fresh shell. It will set some environment variables, alias the commands and create the project work directory if needed. In addition, the script will install svnutils (if needed) and create/checkout unversioned directories (see below) if needed.

#### Developer Work Cycle

A project developer usually goes through the following work cycle:

* Create a (either enhancement or bug-fix) working branch from a (major or minor) branch of a project
  * An enhancement (towards some major feature) will be initiated by branching from some /x to a working branch /x/e\_&lt;date&gt;\_&lt;short\_name&gt;
    * `sv_mkenh` &lt;short\_name&gt; [&lt;x&gt;: _LAST_ ]
  * A bug fix (or minor feature) will be initiated by branching from some /x/x to a new working branch /x/x/f\_&lt;date&gt;\_&lt;short\_name&gt;.
    * `sv_mkfix` &lt;short\_name&gt; [&lt;x.x&gt;: _LAST.LAST_ ]
  * An either command will require the current directory to be ~/work/&lt;project&gt; (this is the situation after calling sv\_init\_&lt;project&gt;) and will visibly result in creating directory ~/work/&lt;project&gt;/&lt;working\_branch\_name&gt; with a working copy of the project all the development work will be performed in.
* Work (yes, actually work!) on some working branch
  * A developer will usually start his day with opening a fresh shell, running sv\_init\_&lt;project&gt;, and changing the directory to a &lt;working\_branch\_name&gt; directory. Any file there can be freely edited. Other file manipulations are shown below.
  * Create a new source-controlled file or add an existing file to the source control.
    * `svmf` &lt;file\_name&gt;
  * Move (rename) or remove a source controlled file or a directory similarly to the regular mv/rm (the regular mv/rm may be "disabled" by alias-obscuring).
    * _Notes_:
      * I don't currently find any reasonable use for a special copy operation; a developer may use a regular cp (and then svmf) for entire-file copy-pastes, but this is deprecated of course.
      * A file or directory is restricted to be unchanged for information safety. One can preliminary "undo" the changes using svn revert command, but this is also deprecated.
    * `svmv` &lt;path&gt; &lt;other\_path&gt;
    * `svrm` &lt;path&gt;
  * Create a new source-controlled directory or add an existing directory to the source control.
    * `svmd` &lt;dir\_name&gt;
* Snapshot/revert some working branch
  * Sometimes you want to make a snapshot of your work before going on, especially if its a looong running task you're working on.
    * `svss` [&lt;path&gt;: .]
  * Alternatively, a developer might want to return to his snapshot if he's got drunk and made too much silly things to his working copy, for instance, or his working copy has got corrupted for some reason. The command below may be run repeatedly to revert the working copy to an even earlier snapshot (up to the very first revision of his working branch) similarly to the undo comand in emacs.
    * _Notes_:
      * This is also the command to run when you want to continue your work on some other machine (to fetch the snapshot from the repository). In the latter case the developer still will have to be in (and probably preliminary create) and/or specify the right directory (~/work/&lt;project&gt;/&lt;working\_branch\_name&gt; if you have the same _working\_branch\_name_ twice in the repository [improbable due to the date-prefix notion], too bad, it will just fetch the first one found).
      * Note that this command will also revert an update performed by the sv\_update command described below if this is the next revision in "the undo stack".
    * `sv_revert` [&lt;path&gt;: .]
* Update the working branch _and_ the working copy with the current state of the base version branch
  * If (and only if) further development requires an update from the base branch due to other developments submitted, a developer will need to update his project working copy state.
  * Note that the command below will automatically snapshot the current working copy state prior to actually making the update if there are any changed files/directories.
  * It is advised that the developer will snapshot the working copy after the update (and after resolving merge conflicts, if any).
    * `sv_update` [&lt;path&gt;: .]
* Finish the work (hooray!)
  * Prior to finishing the work, a project developer will usually update its working branch to see that the code integrates nicely.
  * Finally, after the work on the current working branch (you have to be in its working copy directory) is over, the developer may submit his work. Basically, it will snapshot the working copy (if this hasn't been already done) and notify the project versioner on the completion. The command below may be run repeatedly if you go through several integration iterations.
    * `sv_mkfin` [&lt;path&gt;: .]

#### Versioner Activities

A project versioner will perform the following operations:

* Create a new project
  * The command below results in creating the appropriate directories in the repository and producing the sv\_init\_&lt;project&gt;.[c]sh script for developers in the predefined accessible location (root directory of the project in the repository).
    * `sva_mkproj` &lt;project&gt;
* Create a new major branch
  * This operation is not automated since the meaning can be different, but the final result is a new major branch directory anyway.
* Integrate a branch / Create a new minor/version branch
  * Usually a versioner will integrate some work branches into corresponding parent branch and then run some tests on the resulting code. If the tests are passed, a new child branch (either minor or version) is created. If not, the integration results are discarded and the developers will continue working on their branches.
  * The command below will do the integration (by checking out the current code and merging all the provided working branches, if any) and also ask for confirmation before creating the child branch (the versioner should confirm only if the code is ok, by running tests and stuff) with the name provided as the first parameter.
  * The validity of the new branch name and the working branch names are checked automatically, of course.
    * `sva_mkver` &lt;project&gt; &lt;x.x[.x]&gt; [&lt;working\_branch\_name&gt; [&lt;working\_branch\_name&gt; [...]]]
* Delete obsolete branches (of any kind)
  * TBD

#### Unversioned Stuff

In addition to the "versioned" source directories of a project, there are "unversioned" (but still "revisioned") ones (there may be totally unversioned projects, like svnutils itself). Currently, I clearly see only the (global) 'doc' directory for core documentation (core algorithms, whitepapers, research and stuff); there will also probably be the 'rel' directory containing the project-related release information (a subdirectory for each release). A project developer will neither usually need _all_ of such directories nor perform any of the common source-control actions on them. Therefore, the Subversion-based version management will be different (much more simple) for the unversioned directories.

A developer will be usually unaware of it, but unversioned directories will be directly in the project directory at the repository (like /car/doc), _not_ in the main branch directory or something.

Below are the commands of the working cycle.

* Check-out a file/directory
  * This is the first thing to do when you start working with any unversioned file/directory. This is also the thing to do when you want to update one. The argument of this command should point to an unversioned file/directory (under ~/work/&lt;project&gt;/&lt;unversioned\_directory&gt;).
  * Note that the "check-out" does not imply any subsequent "check-ins".
    * `svco` &lt;path&gt;
* Work
  * This is the same as for the versioned files/directories. The `svmf`, `svmd`, `svmv`, `svrm` commands are valid have the same meanings.
* Check-in a file/directory
  * Note that although technically it is similar to snapshot, the meaning is much more dramatic. This command will "overwrite" the current revision so the whole project may be affected. The argument of this command should point to an unversioned file/directory (under ~/work/&lt;project&gt;/&lt;unversioned\_directory&gt;).
    * `svci` &lt;path&gt;
* Do something weird
  * Well, the above commands should suffice for normal work flow. However, there may be situations when one would want to do something exotic (probably due to some human error, oh, those humans) like reverting some unversioned file to some earlier revision. In this case, an svn expert should be able to help the poor guy.

-- CostaShapiro - 27 May 2005
