#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function

import re
import copy

__metaclass__ = type

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = '''

module: operator_storage

short_description: Process volume specifications to a set of Kubernetes resources

version_added: "2.8"

author: "Fabian von Feilitzsch (@fabianvf)"

description:
  - Processes volume specifications into a set of usable Kubernetes definitions
    to create and use the volumes

options:
  volumes:
    type: dict
    description:
    - Volume specifications to be processed
    required: true
    suboptions:
      volume-name:
        type: str
        required: true
        description:
        - An identifier for the volume entry
        - inline, not an actual parameter
      type:
        type: str
        description:
        - Specifies what type of volume this is
        choices:
        - PersistentVolumeClaim
        - EmptyDir
      mount_path:
        type: path
        required: False
        description:
        - The path in a container the specified volume should be mounted
        - Required for the I(volume_mounts) to be returned
      claim_name:
        type: str
        default: I(prefix)-I(name)
        description:
        - The name of a PersistentVolumeClaim to use or create
        - Required when I(type=PersistentVolumeClaim) and I(create=false)
      size:
        type: str
        description:
        - The size of the volume
        - Required when I(type=PersistentVolumeClaim) and I(create=true)
      create:
        type: bool
        default: False
        description:
        - Whether or not to create a PersistentVolumeClaim if it doesn't already exist
      storage_class_name:
        type: str
        description:
        - overrides the default storage class when creating a PersistentVolumeClaim
      access_modes:
        type: list
        default:
        - ReadWriteOnce
        description:
        - Set the access mode for a volume
        choices:
        - ReadWriteOnce
        - ReadWriteMany
        - ReadOnlyMany
      read_only:
        type: bool
        default: false
        description:
        - Whether or not to mount the volume ReadOnly
  prefix:
    description:
    - Prepended to volume names for easier identification
  namespace:
    type: str
    description:
    - Use to specify an object namespace. Use in conjunction with I(api_version), I(kind), and I(name)
      to identify a specific object.

requirements:
    - "python >= 2.7"
'''

EXAMPLES = '''
'''

RETURN = '''
definitions:
  description:
  - A dict of Kubernetes resource definitions (as python dictionaries) representing
    the Kubernetes resources needed to create the specified volumes
  - Keyed by the same names passed in
  returned: success
  type: dict
volumes:
  description:
  - A dict of Kubernetes volume blocks for use in specifying a volume to be
    attached to a Kubernetes Pod/Deployment/etc
  - Keyed by the same names passed in
  returned: success
  type: dict
volume_mounts:
  description:
  - A dict of Kubernetes volume mount blocks for use in specifying a volume to be
    mounted to a Kubernetes Pod/Deployment/etc
  - Keyed by the same names passed in
  returned: success
  type: dict
'''

TODO = None

class Volume(object):

    def __init__(self, name, spec, namespace, prefix=None):
        self.name = name
        self.prefix = prefix
        self.volume_name = '-'.join(filter(None, [self.prefix, self.name]))
        self.process_spec(spec)
        self.namespace = namespace

    def process_spec(self, spec):
        self.volume_type = spec['type']
        self.read_only = spec.get('read_only', False)
        self.mount_path = spec.get('mount_path')
        if self.volume_type == 'PersistentVolumeClaim':
            self.access_modes = spec.get('access_modes', ['ReadWriteOnce'])
            for mode in self.access_modes:
                if mode not in ['ReadWriteOnce', 'ReadWriteMany', 'ReadOnlyMany']:
                    raise ValueError('access_modes must be in ["ReadWriteOnce", "ReadWriteMany", "ReadOnlyMany"]')
            self.size = spec.get('size')
            self.storage_class_name = spec.get('storage_class_name')
            self.create = spec.get('create', False)
            self.claim_name = spec.get('claim_name', self.volume_name)
            if not self.create and not self.claim_name:
                raise ValueError('You must specify one of create, claim_name')

    def to_definition(self):
        if self.volume_type == 'PersistentVolumeClaim' and self.create:
            return {
                "apiVersion": "v1",
                "kind": "PersistentVolumeClaim",
                "metadata": {
                  "name": self.claim_name,
                  "namespace": self.namespace,
                },
                "spec": {
                    "accessModes": self.access_modes,
                    "resources": {"requests": {"storage": self.size}},
                    "storageClassName": self.storage_class_name,
                }
            }

    def to_volume(self):
        if self.volume_type == 'PersistentVolumeClaim':
            return {
                "name": self.volume_name,
                "persistentVolumeClaim": {"claimName": self.claim_name}
            }
        elif self.volume_type == 'EmptyDir':
            return {
                "name": self.volume_name,
                "emptyDir": {}
            }

    def to_volume_mount(self):
        if self.mount_path:
            return {
                "mountPath": self.mount_path,
                "name": self.volume_name,
                "readOnly": self.read_only
            }


def operator_storage(volumes, namespace, prefix=None):
    volumes = {name: Volume(name, spec, namespace) for name, spec in volumes.items()}
    ret = {"processed_volumes": {}}
    for name, volume in volumes.items():
        ret['processed_volumes'][name] = {
            'definition': volume.to_definition(),
            'volume': volume.to_volume(),
            'volume_mount': volume.to_volume_mount(),
        }
    ret['definitions'] = list(filter(None, [volume.to_definition() for volume in volumes.values()]))
    ret['volumes'] = list(filter(None, [volume.to_volume() for volume in volumes.values()]))
    ret['volume_mounts'] = list(filter(None, [volume.to_volume_mount() for volume in volumes.values()]))
    return ret


class FilterModule(object):
    def filters(self):
        return {
            'operator_storage': operator_storage,
        }
