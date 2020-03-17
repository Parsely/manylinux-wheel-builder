#!/bin/bash
set -e -x

# Install packages required for wheel building
yum install -y zlib-devel bzip2-devel ncurses-devel sqlite-devel \
readline-devel tk-devel gdbm-devel db4-devel libpcap-devel\
xz-devel gpg atlas-devel libev-devel libev snappy-devel freetype-devel \
libpng-devel libffi-devel python-lxml postgresql95-libs \
postgresql95-devel lapack-devel python \
python-devel python-setuptools pcre pcre-devel \
pandoc

# psycopg2 won't build without this
export PG_HOME=/usr/pgsql-9.5
export PATH=/usr/pgsql-9.5/bin:$PATH

# Compile wheels
for PYBIN in /opt/python/*/bin; do
    if [[ "$PYBIN" =~ cp26 ]]; then
        echo "Skipping 2.6 because it's horrible"
        elif [[ "$PYBIN" =~ cp27 ]]; then
        echo "Skipping 2.7 because we don't use it"
        elif [[ "$PYBIN" =~ cp33 ]]; then
        echo "Skipping 3.3 because we don't use it"
        elif [[ "$PYBIN" =~ cp34 ]]; then
        echo "Skipping 3.4 because we don't use it"
        elif [[ "$PYBIN" =~ cp35 ]]; then
        echo "Skipping 3.5 because we don't use it"
    else
        "${PYBIN}/pip" install --upgrade pip wheel
        CFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib" ${PYBIN}/pip wheel cryptography -w wheelhouse/ -f wheelhouse
        "${PYBIN}/pip" wheel -r /io/dev-requirements.txt -w wheelhouse/ -f wheelhouse || true
        # Do another run allowing dev builds, and do it with a separate run per
        # requirement so that one broken prerelease doesn't stop the rest from
        # being build---I'm looking at *you* statsmodel 0.8.0rc1
        cat /io/dev-requirements.txt | tr '\n' '\0' | xargs -0 -I{} bash -c "${PYBIN}/pip wheel --pre {} -w wheelhouse/ -f wheelhouse || true"
    fi
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    if [[ "$whl" =~ none-any ]]; then
        echo "Skipping pure wheel $whl"
        elif [[ "$whl" =~ manylinux ]]; then
        echo "Skipping manylinux wheel $whl"
    else
        auditwheel repair "$whl" --plat $PLAT -w /io/wheelhouse/ || true
    fi
done

# Remove platform-specific wheels
rm -f wheelhouse/*-linux*.whl
