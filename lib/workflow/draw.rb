require 'active_support/inflector'

module Workflow
  module Draw

    # Generates a `dot` graph of the workflow.
    # Prerequisite: the `dot` binary. (Download from http://www.graphviz.org/)
    # You can use this method in your own Rakefile like this:
    #
    #     namespace :doc do
    #       desc "Generate a graph of the workflow."
    #       task :workflow
    #         Workflow::workflow_diagram(Order)
    #       end
    #     end
    #
    # You can influence the placement of nodes by specifying
    # additional meta information in your states and transition descriptions.
    # You can assign higher `weight` value to the typical transitions
    # in your workflow. All other states and transitions will be arranged
    # around that main line. See also `weight` in the graphviz documentation.
    # Example:
    #
    #     state :new do
    #       event :approve, :transitions_to => :approved, :meta => {:weight => 8}
    #     end
    #
    #
    # @param klass A class with the Workflow mixin, for which you wish the graphical workflow representation
    # @param [String] target_dir Directory, where to save the dot and the pdf files
    # @param [String] graph_options You can change graph orientation, size etc. See graphviz documentation
    def self.workflow_diagram(klass, options={})
      options = {
        :name => "#{klass.name.tableize}_workflow".gsub('/', '_'),
        :path => '.',
        :orientation => "landscape",
        :ratio => "fill",
        :format => 'png',
        :font => 'Helvetica'
      }.merge options

      begin
        require 'rubygems'
        require 'graphviz'

        graph = GraphViz.new('G', :rankdir => options[:orientation] == 'landscape' ? 'LR' : 'TB', :ratio => options[:ratio])

        # Add nodes
        klass.workflow_spec.states.each do |_, state|
          node = state.draw(graph)
          node.fontname = options[:font]

          state.events.each do |_, event|
            edge = event.draw(graph, state)
            edge.fontname = options[:font]
          end
        end

        # Generate the graph
        filename = File.join(options[:path], "#{options[:name]}.#{options[:format]}")

        graph.output options[:format] => "'#{filename}'"

    puts "
Please run the following to open the generated file:

open '#{filename}'
"
        graph
      rescue LoadError => e
        $stderr.puts "Could not load the ruby-graphiz gem for rendering: #{e.message}"
        false
      end
    end
  end
end