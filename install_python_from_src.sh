#!/bin/bash


hw_plat=$(uname -p)   # 'i686' or 'x86_64'
el_ver=$(uname -r | sed -r -e 's/^.*\.el([0-9]+)\..*/\1/')   # '6' from  ..el6..
el_str="el${el_ver}"
    
tmpdir=/tmp/pkgs
[[ -d "$tmpdir" ]] || mkdir $tmpdir


croak() {
  echo $1
  exit 1
}

rpmsearch_and_install() {
  pkg_name=$1
  echo -n "|-->  rpmsearch'ing for pkg '$pkg_name' ..."

  rpm_url=$( curl "http://www.rpm-find.net/linux/rpm2html/search.php?query=$pkg_name" 2>/dev/null \
      | perl -ne 'print qq{$1\n} if /(\w+\:\/\/[\w\.\-\/]+\.'"${el_str}\.${hw_plat}"'\.rpm)/' )
  [[ -z "$rpm_url" ]] && croak "rpmsearch for pkg '$pkg_name' couldn't find the URL"
  echo  "\n|-->      rpmsearch found URL: '$rpm_url'"
  rpm_file_base=$(echo $rpm_url | sed -e 's/^.*\///')
  echo -n "|-->  Local-installing pkg '$pkg_name' ..."
  cd $tmpdir && curl -O $rpm_url \
      && sudo yum -y localinstall "./${rpm_file_base}" >/dev/null  \
      && echo "(done)"
}

yum_install_pkg() {
  pkg_name=$1
  echo -n "|-->  Installing pkg '$pkg_name' ..."
  if sudo rpm -q $pkg_name >/dev/null 2>&1 ; then
    echo "skip (installed already)"
  else
    sudo yum -y install "$pkg_name" >/dev/null && echo "done" || rpmsearch_and_install $pkg_name
  fi
}

install_python_from_source() {
    py_ver=$1
    [[ -z "$py_ver" ]] && croak "Specify python version"

    tgt_dir="/usr/local/pythons/python${py_ver}.${el_str}.${hw_plat}"  # Ex pythons/python2.6.6.el6.i686
    command -v $tgt_dir/bin/python && return

    # Pyhapi needs python3. We can stick to Python3.5.3
    # if installing fresh, lets isntall these before

    # In general, before installing Python3, these are recommended
    # During Python3 install, 'ensurepip' may fail if openssl-devel is absent
    # “Ignoring ensurepip failure: pip 8.1.1 requires SSL/TLS”
    # Pyhapi needs pymodule 'readline' which needs 'libncurses'
    # /bin/ld: cannot find -lncurses
    #  # Note: couldn't find rpm for 'tcllib' anywhere
    for pkg in openssl openssl-devel sqlite sqlite-devel zlib zlib-devel bzip2 bzip2-devel \
      expect tcl tcl-devel tclx tclx-devel tk tk-devel tkinter \
      ncurses ncurses-devel readline readline-devel \
      libffi libffi-devel ; do
        yum_install_pkg $pkg
    done

    if [[ -d "$tmpdir" ]]; then
        cd $tmpdir
        python_src_file=Python-${py_ver}
        curl -O "https://www.python.org/ftp/python/${py_ver}/$python_src_file.tgz"
        tar xvfz $python_src_file.tgz && cd $python_src_file   \
            && sudo ./configure --enable-shared --with-ensurepip=install --prefix=$tgt_dir && sudo make && sudo make install
    fi
}


# install_python_from_source '2.7.13'
install_python_from_source '2.6.6'
