require "forwardable"

module Ezid
  #
  # EZID metadata collection for an identifier
  #
  # @api public
  class Metadata
    extend Forwardable
    include Enumerable

    # The metadata elements hash
    attr_reader :elements

    def_delegators :elements, :each, :empty?, :[], :[]=

    # EZID metadata profiles
    PROFILES = %w( erc dc datacite crossref )

    # Public status
    PUBLIC = "public"

    # Reserved status
    RESERVED = "reserved"

    # Unavailable status
    UNAVAILABLE = "unavailable"
    
    # EZID identifier status values
    STATUS_VALUES = [PUBLIC, RESERVED, UNAVAILABLE].freeze

    # EZID internal read-only metadata elements
    INTERNAL_READONLY_ELEMENTS = %w( _owner _ownergroup _created _updated _shadows _shadowedby _datacenter ).freeze

    # EZID internal writable metadata elements
    INTERNAL_READWRITE_ELEMENTS = %w( _coowners _target _profile _status _export _crossref ).freeze        

    # EZID internal metadata elements
    INTERNAL_ELEMENTS = (INTERNAL_READONLY_ELEMENTS + INTERNAL_READWRITE_ELEMENTS).freeze

    # Internal metadata element which are datetime values
    # @note EZID outputs datetime info as epoch seconds.
    DATETIME_ELEMENTS = %w( _created _updated ).freeze
    
    # EZID metadata field/value separator
    ANVL_SEPARATOR = ": "

    # Characters to escape on output to EZID
    ESCAPE_RE = /[%:\r\n]/

    # Character sequence to unescape from EZID
    UNESCAPE_RE = /%\h\h/

    # A comment line
    COMMENT_RE = /^#.*(\r?\n)?/ 

    # A line continuation
    LINE_CONTINUATION_RE = /\r?\n\s+/

    # A line ending
    LINE_ENDING_RE = /\r?\n/

    def initialize(data={})
      @elements = coerce(data)
    end

    # Output metadata in EZID ANVL format
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    # @return [String] the ANVL output
    def to_anvl
      lines = map { |element| element.map { |e| escape(e) }.join(ANVL_SEPARATOR) }
      lines.join("\n").force_encoding(Encoding::UTF_8)
    end

    def to_s
      to_anvl
    end

    # Adds metadata to the collection
    # @param data [String, Hash, Ezid::Metadata] the data to add
    # @return [Ezid::Metadata] the updated metadata
    def update(data)
      elements.update(coerce(data))
      self
    end

    # method_missing is used to provide internal element readers and writers
    def method_missing(name, *args)
      if INTERNAL_ELEMENTS.include?(element = "_#{name}")
        reader(element) 
      elsif name.to_s.end_with?("=") && INTERNAL_READWRITE_ELEMENTS.include?(element = "_#{name}".sub("=", ""))
        writer(element, args.first) 
      else
        super
      end
    end

    private

    def reader(element)
      value = self[element]
      return Time.at(value.to_i) if DATETIME_ELEMENTS.include?(element) && !value.nil?
      value
    end

    def writer(element, value)
      self[element] = value
    end

    # Coerce data into a Hash of elements
    def coerce(data)
      begin
        stringify_keys(data.to_h)
      rescue NoMethodError
        coerce_string(data)
      end
    end

    def stringify_keys(hsh)
      hsh.keys.map(&:to_s).zip(hsh.values).to_h
    end

    # Escape value for sending to EZID host
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    # @param value [String] the value to escape
    # @return [String] the escaped value
    def escape(value)
      value.gsub(ESCAPE_RE) { |m| URI.encode(m) }
    end

    # Unescape value from EZID host (or other source)
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    # @param value [String] the value to unescape
    # @return [String] the unescaped value
    def unescape(value)
      value.gsub(UNESCAPE_RE) { |m| URI.decode(m) }
    end
    
    # Coerce a string of metadata (e.g., from EZID host) into a Hash
    # @param data [String] the string to coerce
    # @return [Hash] the hash of coerced data
    def coerce_string(data)
      data.gsub(COMMENT_RE, "")
        .gsub(LINE_CONTINUATION_RE, " ")
        .split(LINE_ENDING_RE)
        .map { |line| line.split(ANVL_SEPARATOR, 2).map { |v| unescape(v).strip } }
        .to_h
    end

  end
end
