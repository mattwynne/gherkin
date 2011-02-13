require 'json'
require 'gherkin/formatter/model'

module Gherkin
  module Formatter
    module Model
      module HasSteps
        def steps
          @steps ||= []
        end
      end

      module HasExamples
        def examples
          @examples ||= []
        end
      end

      module HasElements
        class ElementsCollection < Array
          attr_reader :backgrounds
          attr_reader :scenarios
          attr_reader :scenario_outlines
          
          def initialize
            @backgrounds = []
            @scenarios = []
            @scenario_outlines = []
          end
          
          def << new_element
            super
            new_element.replay(self)
          end
          
          def background(background)
            @backgrounds << background
          end
          
          def scenario(scenario)
            @scenarios << scenario
          end
          
          def scenario_outline(scenario_outline)
            @scenario_outlines << scenario_outline
          end
        end
        
        def elements
          @elements ||= ElementsCollection.new
        end
        
        def scenarios
          elements.scenarios
        end
        
        def background
          elements.backgrounds.first
        end
        
        def scenario_outlines
          elements.scenario_outlines
        end
      end
    end
    
    class TreeFormatter
      # Creates a new instance that writes the resulting JSON to +io+.
      # If +io+ is nil, the JSON will not be written, but instead a Ruby
      # object can be retrieved with #gherkin_object
      def initialize(receiver)
        raise(ArgumentError, "receiver must implement #feature") unless receiver.respond_to?(:feature)
        @receiver = receiver
      end

      def uri(uri)
      end

      def feature(feature)
        @feature = feature.extend(Gherkin::Formatter::Model::HasElements)
      end

      def steps(steps)
      end

      def background(background)
        @feature.elements << background
        @current = background
      end

      def scenario(scenario)
        @feature.elements << scenario
        @current = @feature.elements.last
      end

      def scenario_outline(scenario_outline)
        @feature.elements << scenario_outline
        @current = @feature.elements.last
      end

      def examples(examples)
        @current.extend(Gherkin::Formatter::Model::HasExamples) unless @current.respond_to?(:examples)
        @current.examples << examples
      end

      def step(step)
        @current.extend(Gherkin::Formatter::Model::HasSteps) unless @current.respond_to?(:steps)
        @current.steps << step
      end

      def eof
        @receiver.feature @feature
      end

    end
  end
end

