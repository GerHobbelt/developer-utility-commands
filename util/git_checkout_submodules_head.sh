#! /bin/bash
#
# HELP/NOTE: get online help by calling with:   -h
#
# 
# checkout all submodules to their desired 'HEAD' bleeding edge revision: MASTER for most.
#

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

cd ..



getopts ":Fhl" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
"F" )
  echo "--- checkout to branch or master with RESET + FORCE ---"
  mode="F"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  ;;

"h" )
  mode="?"
  cat <<EOT
$0 [-F] [-l]

checkout git submodules to the preconfigured branch (master / other).

-F       : apply 'git reset --hard' and 'git checkout --force' to each submodule

-l       : list the submodules which will be checked out to a non-'master' branch

EOT
  popd                                                                                                  2> /dev/null  > /dev/null
  exit 2
  ;;

"l" )
  mode="?"
  cat <<EOT

These submodules have been preconfigured to checkout to non-master branches:

EOT
  ;;

* )
  echo "--- checkout git submodules to master / branch ---"
  mode="R"
  ;;
esac




#git submodule foreach --recursive git checkout master
#
# instead, use the shell to loop through the submodules so we can give any checkout errors the birdy!
if test "$mode" != "?" ; then
    for f in $( git submodule foreach --recursive --quiet pwd ) ; do
        pushd $f                                                                                            2> /dev/null  > /dev/null
        case "$mode" in
F )
            echo "submodule: $f (master, FORCED)"
            git reset --hard
            git checkout master --force
            git reset --hard
      ;;

"?" )
            ;;

R )
            echo "submodule: $f (master)"
            git checkout master
            ;;
        esac
        popd                                                                                                2> /dev/null  > /dev/null
    done
fi

# args: lib localname remote
function checkout_branch {
    if test -d $1 ; then
        pushd $1                                                                                                2> /dev/null  > /dev/null
        case "$mode" in
F )
            echo "submodule: $1, branch: $2 (FORCED)"
            git branch --track $2 origin/$2                                                                            2> /dev/null
            git reset --hard
            git checkout $2 $3 --force
            git reset --hard
            ;;

"?" )
            if test "$2" != "master"; then
                echo "submodule: $1"
                echo "                                         branch: $2"
            fi
            ;;

R )
            echo "submodule: $1, branch: $2"
            git branch --track $2 origin/$2                                                                            2> /dev/null
            git checkout $2 $3
            ;;
        esac
        popd                                                                                                    2> /dev/null  > /dev/null
    fi
}




# better make sure; had trouble a few times...
#checkout_branch lib/CKeditor.development                                       experimental                                $@
#checkout_branch lib/d3                                                         master                                      $@
#checkout_branch lib/elFinder                                                   2.1                                         $@
#checkout_branch lib/elFinder                                                   2.x                                         $@
#checkout_branch lib/elFinder                                                   nao-2.1                                     $@
#checkout_branch lib/elFinder                                                   nao-2.x                                     $@
#checkout_branch lib/highlight                                                  for-npm-install                             $@
#checkout_branch lib/less                                                       release                                     $@
#checkout_branch lib/slickgrid                                                  frozenRowsAndColumns-work                   $@


checkout_branch css/lib/bootstrap-themes-bootswatch                            gh-pages                                    $@
checkout_branch css/lib/Font-Awesome                                           experimental                                $@
checkout_branch css/lib/Font-Awesome/_gh_pages                                 gh-pages                                    $@
checkout_branch lib/backbone                                                   gh-pages                                    $@
checkout_branch lib/backbone-associations                                      gh-pages                                    $@
checkout_branch lib/backbone-fundamentals-book                                 gh-pages                                    $@
checkout_branch lib/backbone-ui                                                validation                                  $@
checkout_branch lib/backbone/.git                                              gh-pages                                    $@
checkout_branch lib/Bootstrap-Form-Builder                                     gh-pages                                    $@
checkout_branch lib/circle-menu                                                gh-pages                                    $@
checkout_branch lib/CKeditor.development                                       major                                       $@
checkout_branch lib/crossfilter                                                gh-pages                                    $@
checkout_branch lib/d3                                                         all_scales_have_subticks                    $@
checkout_branch lib/d3-nvd3-charts                                             gh-pages                                    $@
checkout_branch lib/d3/examples/github.Addepar.ember-table                     gh-pages                                    $@
checkout_branch lib/d3/examples/github.anilomanwar.d3jsExperiments             gh-pages                                    $@
checkout_branch lib/d3/examples/github.artzub.wbgds                            smy                                         $@
checkout_branch lib/d3/examples/github.BertrandDechoux.d3js-sandbox            gh-pages                                    $@
checkout_branch lib/d3/examples/github.calvinmetcalf.leaflet.demos             gh-pages                                    $@
checkout_branch lib/d3/examples/github.fod.jobflow                             gh-pages                                    $@
checkout_branch lib/d3/examples/github.latentflip.violin                       gh-pages                                    $@
checkout_branch lib/d3/examples/github.ramnathv.slidifyExamples                gh-pages                                    $@
checkout_branch lib/d3/examples/github.saranyan.commerce_wheel                 gh-pages                                    $@
checkout_branch lib/d3/examples/github.scottcheng.bj-air-vis                   gh-pages                                    $@
checkout_branch lib/d3/examples/github.vogievetsky.IntroD3                     gh-pages                                    $@
checkout_branch lib/dropin-require                                             gh-pages                                    $@
checkout_branch lib/elFinder                                                   extra-fixes                                 $@
checkout_branch lib/highlight                                                  master                                      $@
checkout_branch lib/iscroll                                                    v5                                          $@
checkout_branch lib/jasmine/pages                                              gh-pages                                    $@
checkout_branch lib/jasmine                                                    master                                      $@
checkout_branch lib/jquery-dirtyforms/lib/facebox                              cssified                                    $@
checkout_branch lib/jquery-facebox                                             cssified                                    $@
checkout_branch lib/jQuery-File-Upload                                         gh-pages                                    $@
checkout_branch lib/jquery-form-accordion                                      gh-pages                                    $@
checkout_branch lib/jquery-print-in-page                                       gh-pages                                    $@
checkout_branch lib/jquery-sparkline                                           takacsv-work                                $@
checkout_branch lib/jquery-ui-keyboard                                         gh-pages                                    $@
checkout_branch lib/jquery-waypoints                                           gh-pages                                    $@
checkout_branch lib/json3/vendor/spec                                          gh-pages                                    $@
checkout_branch lib/large-local-storage                                        gh-pages                                    $@
checkout_branch lib/less                                                       master                                      $@
checkout_branch lib/Modernizr                                                  improvedAsyncTestSupport                    $@
checkout_branch lib/moment                                                     develop                                     $@
checkout_branch lib/mousetrap                                                  wrapping-specific-elements                  $@
checkout_branch lib/noty                                                       gh-pages                                    $@
checkout_branch lib/one-color/slides/3rdparty/CSSS                             gh-pages                                    $@
checkout_branch lib/pie-menu                                                   gh-pages                                    $@
checkout_branch lib/radial-responsive-menu                                     gh-pages                                    $@
checkout_branch lib/reveal.js                                                  hakim-dev                                   $@
checkout_branch lib/slickgrid                                                  k0stya-rowspan                              $@
checkout_branch lib/spectrum                                                   no-color                                    $@
checkout_branch lib/spectrum/lib/TinyColor                                     gh-pages                                    $@
checkout_branch lib/spin                                                       gh-pages                                    $@
checkout_branch lib/square-responsive-menu                                     gh-pages                                    $@
checkout_branch lib/SyntaxHighlighter                                          highlight-and-annotate-per-line             $@
checkout_branch lib/TinyColor                                                  gh-pages                                    $@
checkout_branch lib/zoom                                                       for-revealJS                                $@
checkout_branch php/lib/opauth-docs                                            gh-pages                                    $@
checkout_branch php/lib/PHPExcel                                               develop                                     $@
checkout_branch php/lib/phpmailer                                              smtp-refactor                               $@
checkout_branch util/docco                                                     jump_menu                                   $@
checkout_branch util/docco/lib/highlight.js                                    for-npm-install                             $@
checkout_branch util/javascriptlint                                            working-rev                                 $@
checkout_branch util/jison                                                     master                                      $@
checkout_branch util/jison/gh-pages                                            gh-pages                                    $@
checkout_branch util/jsbeautifier                                              gh-pages                                    $@
checkout_branch util/phpDocumentor                                             develop                                     $@


popd                                                                                                    2> /dev/null  > /dev/null

