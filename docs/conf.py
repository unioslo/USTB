import os
import sys

project = 'USTB'
copyright = '2025, University of Oslo'
author = 'USTB Contributors'

extensions = [
    'sphinx.ext.autodoc',
    'sphinxcontrib.matlab',
]

this_dir = os.path.dirname(os.path.abspath(__file__))
# Python API (docs/python): import ustb from the repository; its dependencies
# must be installed (the website workflow installs ./python)
sys.path.insert(0, os.path.abspath(os.path.join(this_dir, '..', 'python', 'src')))
matlab_src_dir = os.path.abspath(os.path.join(this_dir, '..'))
primary_domain = 'mat'

exclude_patterns = ['_build']

html_theme = 'sphinx_rtd_theme'
html_static_path = []

matlab_short_links = True
matlab_keep_package_prefix = False

rst_prolog = """
.. |rarr| unicode:: U+2192 .. right arrow
"""


def setup(app):
    """Parse Google-style docstrings (napoleon) for the Python API only.

    Adding sphinx.ext.napoleon to extensions would also reformat the MATLAB
    docstrings, so its docstring handler is connected for ustb.* objects only.
    """
    from sphinx.ext import napoleon

    values = napoleon.Config._config_values
    if isinstance(values, dict):  # Sphinx < 9: {name: (default, rebuild)}
        values = [(name,) + tuple(v) for name, v in values.items()]
    for name, default, rebuild, *_ in values:
        app.add_config_value(name, default, rebuild)

    def python_only(app, what, name, obj, options, lines):
        if name.startswith('ustb.'):
            napoleon._process_docstring(app, what, name, obj, options, lines)

    app.connect('autodoc-process-docstring', python_only)
