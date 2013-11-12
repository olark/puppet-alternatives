puppet-alternatives
===================

Manage Debian alternatives symlinks.
This module is based on the module by Adrien Thebo (adrien@puppetlabs.com)
Added support for Red Hat Linux and derivatives.

The Red Hat version also has a type 'alternative' that supports
adding/removing individual alternative paths and optional slave links.

This module should work on any Debian or Red Hat based distribution, or really any
distribution that has a reasonable `update-alternatives` file.

Synopsis
--------

Using `puppet resource` to inspect alternatives

    root@master:~# puppet resource alternatives
    alternatives { 'aptitude':
      path => '/usr/bin/aptitude-curses',
    }
    alternatives { 'awk':
      path => '/usr/bin/mawk',
    }
    alternatives { 'builtins.7.gz':
      path => '/usr/share/man/man7/bash-builtins.7.gz',
    }
    alternatives { 'c++':
      path => '/usr/bin/g++',
    }
    alternatives { 'c89':
      path => '/usr/bin/c89-gcc',
    }
    alternatives { 'c99':
      path => '/usr/bin/c99-gcc',
    }
    alternatives { 'cc':
      path => '/usr/bin/gcc',
    }

- - -

Using `puppet resource` to update an alternative

    root@master:~# puppet resource alternatives editor
    alternatives { 'editor':
      path => '/bin/nano',
    }
    root@master:~# puppet resource alternatives editor path=/usr/bin/vim.tiny
    notice: /Alternatives[editor]/path: path changed '/bin/nano' to '/usr/bin/vim.tiny'
    alternatives { 'editor':
      path => '/usr/bin/vim.tiny',
    }

- - -

Using the alternatives resource in a manifest:

    class ruby::193 {

      package { 'ruby1.9.3':
        ensure => present,
      }

      # Will also update gem, irb, rdoc, rake, etc.
      alternatives { 'ruby':
        path    => '/usr/bin/ruby1.9.3',
        require => Package['ruby1.9.3'],
      }
    }

    # magic!
    include ruby::193

- - -


Managing individual paths with the `alternative` type
-----------------------------------------------------
This type handles individual entries in a file in /var/lib</dpkg>/alternatives.
If you create an alternative for which there is no such file yet, it will be automatically created.
If you remove the last alternative in a file, the file is automatically deleted.

The title of this resource is composite: <name>:<path> where name is a generic name of the alternative
(e.g. 'editor') and path is an actual file on the file system (e.g. '/usr/bin/vim')
The link attribute is normally /usr/bin/<name> (this is the default value)
The default value for priority is '10'

After making modifications using this resource, it is possible that the alternative changes
to manual mode. If this is not what you want, you can change it back to auto mode using the
alternatives resource.

- - - 

Examples:

    alternative { 'test2:/usr/bin/vmstat':
      ensure   => present,
      link     => '/usr/bin/test2',
      priority => '2',
    }

    alternative { 'editor:/usr/bin/vim':
      ensure   => present,
    }

- - - 

With slave links: ( = hash or array of hashes)

    alternative { 'editor:/usr/bin/vim':
      ensure => present,
      slave  => [{name => "t1", link => "/usr/bin/t1", path => "/usr/bin/xyz"},
                 ...
                ],
    }

- - - 

Contact
-------

  * Source code: https://github.com/cegeka/puppet-alternatives
  * Issue tracker: https://github.com/cegeka/puppet-alternatives/issues
