#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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
# = result.rb
#
# == Description
#
# This file defines the ResultService class.
#

require 'omf-common/oml/sequel_server'
require 'omf-aggmgr/ogs/legacyGridService'

require 'stringio'

#
# This class defines a Service to access the measurement results for a given
# performed experiment. These results are stored in a Database. The only
# database format currently supported is SQLite 3.
#
# IMPORTANT: this 'ResultService' needs to be co-located with the Oml2ServerService.
# In other words, the 'result' service needs to be running on the same server as the
# 'oml2' service.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
#
class Result2Service < LegacyGridService

  # used to register/mount the service, the service's url will be based on it
  name 'result2'
  description 'Service to access and query experiment measurement databases'
  @@factory = nil
  @@res_logger = nil
  @@mutex = Mutex.new
  
  RESULT2_NS = 'http://schema.mytestbed.net/am/result/2/'

  #
  # Implement the 'query' service which takes a relational algebra description as defined
  # by the Arel package and returns the result in a variety of formats depending on the 
  # 'format' option.
  #
  s_description %{This service takes a relational algebra description as defined
  by the Arel package and included in an XML serialised form in the body of this message
  and returns the result in a variety of formats as indicated by the 'format' option.}
  #s_param :format, 'xml | json | cvs', 'Format to return result in.', "xml"
  service 'query' do |req, res|
    # Retrieve the request parameter
#    format = getParamDef(req, 'format', 'xml')
#    req.each do |k, v| puts "#{k}: #{v}" end
    begin
      do_query(req, res)
    rescue Exception => ex
      error ex
      res.status = 500
      res.body = "<error>#{ex}</error>"
      res['Content-Type'] = "text/xml"
    end
  end

  def self.do_query(req, res)
    body = req.body
    error "No result request (body) found" if body.empty?
    error "Service instantion error" unless @@factory

    #puts body.inspect
    doc = REXML::Document.new(body)
    request = doc.root
    unless request.name == 'request'
      throw "Request needs to start with 'request' but does start with '#{request.name}'"
      return
    end
    
    unless qel = request.elements['query']
      throw "Request does not contain a 'query'."
      return
    end

    @@mutex.synchronize do
      q = OML::Sequel::XML::Server::Query.new(qel, @@factory, @@res_logger).relation
      debug q.inspect
      
      resp_opts = {:req_id => request.attributes['id'] }
      #puts resp_opts.inspect
      if fel = request.elements['/request/result/format']
        format = fel.text.downcase
      else
        format = 'xml'
      end
      case format
        when 'xml'
          reply = formatXML(q, resp_opts)
          res.body = reply
          res['Content-Type'] = "text/xml"
        when 'json'
          reply = formatJSON(q, resp_opts)
          res.body = reply
          res['Content-Type'] = "text/json"
        when 'csv'
          reply = formatCSV(q, resp_opts)
          res.body = reply
          res['Content-Type'] = "text/csv"
        else
          throw "Unknown reply format '#{format}'"
      end
    end
  end
  
  def self.formatXML(q, resp_opts)
    require 'rexml/document'
    
    doc = REXML::Document.new 
    doc << REXML::XMLDecl.new
    res = doc.add_element('response')
    res.add_namespace(RESULT2_NS)
    if ref_id = resp_opts[:req_id]
      res.add_attribute('refid', ref_id)
    end
    schema_el = res.add_element('schema')
    rows_el = res.add_element('rows')    
    row_count = 0
    cols = q.columns      
    q.each do |r|
      if (row_count == 0)
        desc = q.row_description(r)
        cols.each do |name|
          schema_el.add_element('col', {
            'name' => name,
            'type' => desc[name]
          })
        end
      end 
      rel = rows_el.add_element('r')
      cols.each do |n|
        #puts re
        rel.add_element('c').text = r[n].to_s
      end
      row_count += 1
    end
    rows_el.add_attribute('count', row_count.to_s)
    res = StringIO.new
    doc.write(res)
    res.string
  end

  def self.formatJSON(q, resp_opts)
    result = {}
    response = result['response'] = {}
    if ref_id = resp_opts[:req_id]
      response['refid'] = ref_id
    end
    first = true
    schema = response['schema'] = []
    rows = response['rows'] = []
    cols = q.columns      
    q.each do |r|
      if (first)
        desc = q.row_description(r)
        cols.each do |name|
          schema << {:name => name, :type => desc[name]}
        end
        first = false
      end 
      rows << cols.collect do |n| r[n] end 
    end
    reply = result.to_json
    reply
  end
  
  COMMA_SEPARATOR = ';'

  def self.formatCSV(q, resp_opts)
    first = true
    res = StringIO.new
    cols = q.columns
    reply = q.each do |r|
      if (first)
        desc = q.row_description(r)
        res << '# '
        cols.each do |name|
          res << name << ':' << desc[name] << ' '
        end
        first = false
      end 
      res << "\n"
      res << cols.collect do |c| r[c] end.join(COMMA_SEPARATOR)
    end
    res.string
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    opts = {}
    config.each do |key, val| opts[key.to_sym] = val end 
    @@factory = OML::Sequel::XML::Server::RepositoryFactory.new(opts)
    @@res_logger = MObject.logger('result2')
  end
end
