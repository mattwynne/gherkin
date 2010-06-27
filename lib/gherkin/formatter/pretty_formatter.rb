# encoding: utf-8
require 'gherkin/formatter/colors'
require 'gherkin/formatter/monochrome_format'
require 'gherkin/formatter/argument'
require 'gherkin/formatter/escaping'
require 'gherkin/native'

module Gherkin
  module Formatter
    class Keyword
      attr_reader :comments, :tags, :id, :name, :description, :line
      
      def initialize(comments, tags, id, name, description, line = nil)
        @comments, @tags, @id, @name, @description, @line = comments, tags, id, name, description, line
      end
    end
    
    class Feature < Keyword
      def initialize(comments, tags, name, description)
        super(comments, tags, "Feature:", name, description)
      end
    end
    
    class Background < Keyword
      def initialize(comments, name, description, line)
        super(comments, [], "Background:", name, description, line)
      end
    end
    
    class PrettyPrinter
      if(RUBY_VERSION =~ /^1\.9/)
        START = /#{'^'.encode('UTF-8')}/
        TRIPLE_QUOTES = /#{'"""'.encode('UTF-8')}/
      else
        START = /^/
        TRIPLE_QUOTES = /"""/
      end

      def initialize(io)
        @io = io
      end
      
      def feature(feature)
        print_keyword(feature)
      end
      
      def background(background)
        @io.puts
        print_keyword(background, '  ')
      end
      
      private
      
      def print_keyword(keyword, indenting = '')
        print_comments(keyword.comments, indenting)
        print_tags(keyword.tags, indenting)
        @io.print "#{indenting}#{keyword.id} #{keyword.name}"
        @io.print "#{indented_element_uri!(keyword.id, keyword.name, keyword.line)}" if keyword.line
        @io.print "\n"
        print_description(keyword.description, "#{indenting}  ", false)
      end
      
      def print_tags(tags, indent)
        @io.write(tags.empty? ? '' : indent + tags.join(' ') + "\n")
      end

      def print_comments(comments, indent)
        @io.write(comments.empty? ? '' : indent + comments.join("\n#{indent}") + "\n")
      end

      def print_description(description, indent, newline=true)
        if description != ""
          @io.puts indent(description, indent)
          @io.puts if newline
        end
      end
      
      def indent(string, indentation)
        string.gsub(START, indentation)
      end
      
      def indented_element_uri!(keyword, name, line)
        return '' if @max_step_length.nil?
        l = (keyword+name).unpack("U*").length
        @max_step_length = [@max_step_length, l].max
        indent = @max_step_length - l
        ' ' * indent + ' ' + comments("# #{@uri}:#{line}", @monochrome)
      end
    end
    
    class PrettyFormatter
      native_impl('gherkin')

      include Colors
      include Escaping

      def initialize(io, monochrome)
        @io = io
        @monochrome = monochrome
        @format = MonochromeFormat.new #@monochrome ? MonochromeFormat.new : AnsiColorFormat.new
        @printer = PrettyPrinter.new(io)
      end

      def feature(comments, tags, keyword, name, description, uri)
        @uri = uri
        @printer.feature(Feature.new(comments, tags, name, description))
      end

      def background(comments, keyword, name, description, line)
        @printer.background(Background.new(comments, name, description, line))
      end

      def scenario(comments, tags, keyword, name, description, line)
        @io.puts
        print_comments(comments, '  ')
        print_tags(tags, '  ')
        @io.puts "  #{keyword}: #{name}#{indented_element_uri!(keyword, name, line)}"
        print_description(description, '    ')
      end

      def scenario_outline(comments, tags, keyword, name, description, line)
        scenario(comments, tags, keyword, name, description, line)
      end

      def examples(comments, tags, keyword, name, description, line, examples_table)
        @io.puts
        print_comments(comments, '    ')
        print_tags(tags, '    ')
        @io.puts "    #{keyword}: #{name}"
        print_description(description, '    ')
        table(examples_table)
      end

      def step(comments, keyword, name, line, multiline_arg, status, exception, arguments, stepdef_location)
        status_param = "#{status}_param" if status
        name = Gherkin::Formatter::Argument.format(name, @format, (arguments || [])) 

        step = "#{keyword}#{name}"
        step = self.__send__(status, step, @monochrome) if status

        print_comments(comments, '    ')
        @io.puts("    #{step}#{indented_step_location!(stepdef_location)}")
        case multiline_arg
        when String
          py_string(multiline_arg)
        when Array
          table(multiline_arg)
        when NilClass
        else
          raise "Bad multiline_arg: #{multiline_arg.inspect}"
        end
      end

      def syntax_error(state, event, legal_events, line)
        raise "SYNTAX ERROR"
      end

      def eof
      end

      # This method can be invoked before a #scenario, to ensure location arguments are aligned
      def steps(steps)
        @step_lengths = steps.map {|keyword, name| (keyword+name).unpack("U*").length}
        @max_step_length = @step_lengths.max
        @step_index = -1
      end

      def table(rows)
        cell_lengths = rows.map do |row| 
          row.cells.map do |cell| 
            escape_cell(cell).unpack("U*").length
          end
        end
        max_lengths = cell_lengths.transpose.map { |col_lengths| col_lengths.max }.flatten

        rows.each_with_index do |row, i|
          row.comments.each do |comment|
            @io.puts "      #{comment}"
          end
          j = -1
          @io.puts '      | ' + row.cells.zip(max_lengths).map { |cell, max_length|
            j += 1
            color(cell, nil, j) + ' ' * (max_length - cell_lengths[i][j])
          }.join(' | ') + ' |'
        end
      end

    private

      def py_string(string)
        @io.puts "      \"\"\"\n" + escape_triple_quotes(indent(string, '      ')) + "\n      \"\"\""
      end

      def exception(exception)
        exception_text = "#{exception.message} (#{exception.class})\n#{(exception.backtrace || []).join("\n")}".gsub(/^/, '      ')
        @io.puts(failed(exception_text, @monochrome))
      end

      def color(cell, statuses, col)
        if statuses
          self.__send__(statuses[col], escape_cell(cell), @monochrome) + (@monochrome ? '' : reset)
        else
          escape_cell(cell)
        end
      end

      if(RUBY_VERSION =~ /^1\.9/)
        START = /#{'^'.encode('UTF-8')}/
        TRIPLE_QUOTES = /#{'"""'.encode('UTF-8')}/
      else
        START = /^/
        TRIPLE_QUOTES = /"""/
      end

      def indent(string, indentation)
        string.gsub(START, indentation)
      end

      def escape_triple_quotes(s)
        s.gsub(TRIPLE_QUOTES, '\"\"\"')
      end

      def print_tags(tags, indent)
        @io.write(tags.empty? ? '' : indent + tags.join(' ') + "\n")
      end

      def print_comments(comments, indent)
        @io.write(comments.empty? ? '' : indent + comments.join("\n#{indent}") + "\n")
      end

      def print_description(description, indent, newline=true)
        if description != ""
          @io.puts indent(description, indent)
          @io.puts if newline
        end
      end

      def indented_element_uri!(keyword, name, line)
        return '' if @max_step_length.nil?
        l = (keyword+name).unpack("U*").length
        @max_step_length = [@max_step_length, l].max
        indent = @max_step_length - l
        ' ' * indent + ' ' + comments("# #{@uri}:#{line}", @monochrome)
      end

      def indented_step_location!(location)
        return '' if location.nil?
        indent = @max_step_length - @step_lengths[@step_index+=1]
        ' ' * indent + ' ' + comments("# #{location}", @monochrome)
      end
    end
  end
end