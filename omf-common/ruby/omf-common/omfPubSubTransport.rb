#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = omfPubSubTransport.rb
#
# == Description
#
# This file implements a generic Publish/Subscribe transport to be used by the 
# various OMF entities.
#
require "omf-common/omfXMPPServices"
require "omf-common/omfCommandObject"
require 'omf-common/mobject'

# 
# This class defines a generic PubSub Transport  
# Currently, this PubSub Transport is done over XMPP, and this class is using
# the third party library XMPP4R.
# OMF Entities should subclass this class to customise their transport with 
# their specific send/receive pre-processing tasks.
#
class OMFPubSubTransport < MObject

  @@instance = nil

  def self.instance()
    @@instance
  end

  def self.init()
    raise "PubSub Transport already started" if @@instance
    @@instance = self.new()
  end

  

  # Names for constant PubSub nodes
  DOMAIN = "OMF"
  RESOURCE = "resources"
  SYSTEM = "system"

  def slice_node(slice)
    "/#{DOMAIN}/#{slice}"
  end

  def exp_node(slice, experiment)
    "#{slice_node(slice)}/#{experiment}"
  end

  def res_node(slice, resource = nil)
    if resource == nil
      "#{slice_node(slice)}/#{RESOURCE}"
    else
      "#{resources_node(slice)}/#{resource}"
    end
  end

  def sys_node(resource = nil)
    if resource == nil
      "/#{DOMAIN}/#{SYSTEM}"
    else
      "#{system_node}/#{resource}"
    end
  end

  def sys_node?(node_name)
    if node_name =~ /#{system_node}\/(.*)/ then
      $1
    else
      nil
    end
  end

end

