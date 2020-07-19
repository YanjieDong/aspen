require 'active_support/core_ext/string/inflections'
require 'aspen/statement'

module Aspen
  class Node

    extend Dry::Monads[:maybe]

    attr_reader :label, :attributes, :nickname
    attr_writer :nickname

    def initialize(label: , attributes: {})
      @label      = label
      @attributes = attributes
      @nickname   = nickname_from_first_attr_value
    end

    def nickname_from_first_attr_value
      "#{@label}-#{@attributes.values.first}".parameterize.underscore
    end

    # Short (S) Form: (Johnny B. Goode), (Hélène)
    SHORT_FORM = /\(([[[:alpha:]][[:digit:]]\s\.]+?)\)/

    # Default-Attribute (DA) Form: (Employer, UMass Boston)
    DEFAULT_ATTR_FORM = /\(([[:alpha:]]+,\s[[[:alpha:]][[:digit:]]\s\.]+)\)/

    # TODO:
    # Full Cypher (F) Form: (Employer name: "UMass Boston", location: "William Morrissey Blvd.")
    FULL_FORM = Aspen::Statement::NODE


    def to_cypher
      if nickname
        "(#{nickname}:#{label} #{ attribute_string })"
      else
        "(#{label} #{ attribute_string })"
      end
    end

    def nickname_node
      "(#{nickname})"
    end

    def attribute_string
      attributes.to_s.
        gsub(/"(?<token>[[:alpha:]_]+)"=>/, '\k<token>: ').
        # This puts a single space inside curly braces.
        gsub(/\{(\s*)/, "{ ").
        gsub(/(\s*)\}/, " }")
    end

    def ==(other)
      label      == other.label &&
      attributes == other.attributes &&
      nickname   == other.nickname
    end

    def self.from_result(result, context)
      type_array, attrs = result
      _, label = type_array

      from_text(attrs, context, label)
    end

    def self.from_text(given_node_text, context, given_label = nil)

      node_text = if given_label
        given_node_text.gsub(/(^\(?)/, "(").gsub(/(\)?$)/, ")")
      else
        given_node_text
      end

      node_info = case node_text
      when SHORT_FORM
        label = Maybe(given_label)
        attr_value = node_text.match(SHORT_FORM).captures.first
        { label:      label,
          attributes: [
            {
              attr_name:  None(),
              attr_value: Maybe(default_tag(attr_value))
            }
          ]
        }
      when DEFAULT_ATTR_FORM
        label, _, attr_value = node_text.match(DEFAULT_ATTR_FORM).captures.first.partition(", ")
        # TODO: Validate form
        { label:      Maybe(label),
          attributes: [
            {
              attr_name:  None(),
              attr_value: Maybe(default_tag(attr_value))
            }
          ]
        }
      when FULL_FORM # Accepts any node
        assert_node_format(node_text)
      else
        raise Aspen::Error, <<~ERROR
          The node is not formatted correctly. It should either be like
          - (Matt), with a `default` statement in the config, or
          - (Employer, UMass Boston), with a `default_attribute` statement in the config

          Instead, it was
            #{node_text}
        ERROR
      end

      label = node_info[:label].value_or(context.default_node_label)

      attribute_set = node_info[:attributes].inject(Hash.new({})) do |hash_obj, element|
        attr_name = element[:attr_name].value_or(
          context.default_attr_name_for_label(label)
        )
        attr_value = element[:attr_value].value!
        hash_obj[attr_name] = attr_value
        hash_obj
      end

      new(
        label: label,
        attributes: attribute_set,
        nickname: "#{label}-#{attribute_set.values.first}".parameterize.underscore
      )
    end

    INNER_CONTENT = /\((.*?)\)/
    LABEL = /^([[:alpha:]]+)$/
    BRACKETED_CONTENT = /^{(.*)}$/

    def self.assert_node_format(full_form_string)
      data_string = full_form_string.match(INNER_CONTENT).captures.first
      label_part, _, attrs_part = data_string.partition(" ")
      maybe_label = Maybe(label_part)
      maybe_attrs = Maybe(attrs_part)
      if maybe_label.value_or("").match?(LABEL) && maybe_attrs.value_or("").match?(BRACKETED_CONTENT)

        attr_string = maybe_attrs.value!.match(BRACKETED_CONTENT).captures.first
        kv_pairs = attr_string.split(",").map { |e| e.split(":").map(&:strip) }
        attribute_set = kv_pairs.inject([]) do |arr, pair|
          k, v = *pair
          arr << { attr_name: Maybe(k), attr_value: Maybe(tag(v)) }
          arr
        end
        { label: maybe_label, attributes: attribute_set }
      else
        raise Aspen::Error, <<~ERROR
          The node was not formatted correctly. The original text was:
            #{full_form_string}

          The expected format for "full Cypher form" looks like:
            (Person { name: 'Matt', age: 31 })

          The label was '#{maybe_label.value_or("EMPTY")}' and did not match #{LABEL.inspect}.
          The attribute set was '#{maybe_attrs.value_or("EMPTY")}' and did not match #{BRACKETED_CONTENT.inspect}.

          error code: 3
        ERROR
      end
    end

    STRING  = /^"(.+)"$/
    INTEGER = /^([\d,]+)$/
    FLOAT   = /^([\d,]+\.\d+)$/

    def self.tag(token, for_template = false, context = nil)
      case token
      when STRING
        string_token = token.match(STRING).captures.first.to_s
        for_template ? "\"#{string_token}\"" : string_token
      when INTEGER then token.match(INTEGER).captures.first.delete(',').to_i
      when FLOAT   then token.match(FLOAT).captures.first.delete(',').to_f
      else
        # Try to match a node.
        if for_template && context
          begin
            parentheses_token = token.gsub(/(^\(?)/, "(").gsub(/(\)?$)/, ")")
            from_text(parentheses_token, context)
          rescue Aspen::Error # the one above
            raise Aspen::Error, <<~ERROR
              We couldn't tell what type of value this was supposed to be:
                #{token.inspect}

              We can detect strings, integers, and floats (a.k.a. decimals).

              error code: 1
            ERROR
          end
        else
          raise Aspen::Error, <<~ERROR
            We couldn't tell what type of value this was supposed to be:

              #{token.inspect}

            We can detect strings, integers, and floats (a.k.a. decimals).

            error code: 2
          ERROR
        end
      end
    end

    def self.default_tag(token)
      tag(token)
      # SMELL: Exceptions as control flow
    rescue Aspen::Error
      token
    end
  end
end
