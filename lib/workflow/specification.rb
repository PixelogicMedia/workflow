require 'workflow/state'
require 'workflow/event'
require 'workflow/event_collection'
require 'workflow/errors'

module Workflow
  class Specification
    attr_accessor :states, :initial_state, :meta,
      :on_transition_proc, :before_transition_proc, :after_transition_proc, :on_error_proc

    def initialize(meta = {}, &specification)
      @states = Hash.new
      @meta = meta
      instance_eval(&specification)
    end

    def state_names
      states.keys
    end

    private

    def state(name, meta = {:meta => {}}, &events_and_etc)
      # meta[:meta] to keep the API consistent..., gah
      new_state = Workflow::State.new(name, self, meta[:meta])
      @initial_state = new_state if @states.empty?
      @states[name.to_sym] = new_state
      @scoped_state = new_state
      @meta = meta
      instance_eval(&events_and_etc) if events_and_etc
    end

    def handler(klass)
      @scoped_state.handler = klass
      @scoped_state.on_entry = Proc.new {klass.new(self).on_entry} if klass.method_defined?(:on_entry)
      @scoped_state.on_exit = Proc.new {klass.new(self).on_exit} if klass.method_defined?(:on_exit)
    end

    def event(name, args = {}, &action)
      target = args[:transitions_to] || args[:transition_to]
      condition = args[:if]
      handler = @scoped_state.handler
      handler_method = "can_transition_to_#{target}?".to_sym
      if handler.present? && handler.method_defined?(handler_method)
        condition ||= Proc.new {|context| handler.new(context).try(handler_method)}
      end
      raise WorkflowDefinitionError.new(
        "missing ':transitions_to' in workflow event definition for '#{name}'") \
        if target.nil?
      @scoped_state.events.push(
        name, Workflow::Event.new(name, target, condition, (args[:meta] or {}), &action)
      )
    end

    def on_entry(&proc)
      @scoped_state.on_entry = proc
    end

    def on_exit(&proc)
      @scoped_state.on_exit = proc
    end

    def after_transition(&proc)
      @after_transition_proc = proc
    end

    def before_transition(&proc)
      @before_transition_proc = proc
    end

    def on_transition(&proc)
      @on_transition_proc = proc
    end

    def on_error(&proc)
      @on_error_proc = proc
    end
  end
end
