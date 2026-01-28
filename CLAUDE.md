# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


## Project Overview

This is a custom atomic Linux distribution that provides images for a number of common use-cases, such as: servers, desktops, and gaming machines. Images are produced by extending a range of Atomic Linux distributions with modifications, customizations, and fixes that suit each use case, along with a set of extensions to support specific hardware configurations. Image are built and published automatically via GitHub Actions.

## Image Definition

Images for this distribution are defined in the images.yaml file. The file contains target descriptors in a hierarchal structure designed to be compact while also allowing for full customization of individual build targets.

Each entry in the `targets` array defines a use-case and its possible permutations. Entries are hierarchally structured such that subsequent layers can override properties set by prior layers. 

The first level in the image hierarchy defines the common properties and defaults for all permutations. Subsequent levels are named (e.g. variants, configurations) for semantic clarity, but should all behave the same, in that they provide the ability to specify values for previously-unset properties or override values set by previous layers.

Not all property values can be overridden. The `name` property cannot be directly overridden on any object, and should instead be appended to along with a hyphen ("-") as a separator (e.g. server-hci-nvidia).

The top-level `tags` property defines the valid values for the `tags` property defined for each image

### Notable Properties

- **targets**: An array of objects that define the build properties for a 
specific use-case
- **variants**: An array of objects that describe the property modifications that should be applied when building images for a specific scenario or context for relevant to the parent use-case
- **configurations**: An array of objects that describe the property modifications that should be applied when building images for a specific hardware configuration or environment
- **upstream-image**: The upstream container repository on which a given image is based
