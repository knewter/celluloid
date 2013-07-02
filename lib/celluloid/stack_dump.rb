module Celluloid
  class StackDump
    module DisplayBacktrace
      def display_backtrace(backtrace, output)
        if backtrace
          output << "\t" << backtrace.join("\n\t") << "\n\n"
        else
          output << "EMPTY BACKTRACE\n\n"
        end
      end
    end

    class TaskState < Struct.new(:task_class, :type, :meta, :suspend_meta, :status, :backtrace)
    end

    class ActorState
      include DisplayBacktrace

      attr_accessor :subject_id, :subject_class, :name
      attr_accessor :status, :tasks
      attr_accessor :backtrace

      def dump
        string = ""
        string << "Celluloid::Actor 0x#{subject_id.to_s(16)}: #{subject_class}"
        string << " [#{name}]" if name
        string << "\n"

        if status == :idle
          string << "State: Idle (waiting for messages)\n"
          display_backtrace backtrace, string
        else
          string << "State: Running (executing tasks)\n"
          display_backtrace backtrace, string
          string << "Tasks:\n"

          tasks.each_with_index do |task, i|
            string << "  #{i+1}) #{task.task_class}[#{task.type}]: #{task.status}\n"
            string << "      #{task.meta.inspect}\n"
            string << "      sm: #{task.suspend_meta.inspect}\n"
            display_backtrace task.backtrace, string
          end
        end

        string
      end
    end

    class ThreadState < Struct.new(:thread_id, :backtrace)
      include DisplayBacktrace

      def dump
        string = ""
        string << "Thread 0x#{thread_id.to_s(16)}:\n"
        display_backtrace backtrace, string
        string
      end
    end

    attr_accessor :actors, :threads

    def initialize
      @actors  = []
      @threads = []

      snapshot
    end

    def snapshot
      Thread.list.each do |thread|
        if thread.celluloid?
          next unless thread.role == :actor
          @actors << snapshot_actor(thread.actor) if thread.actor
        else
          @threads << snapshot_thread(thread)
        end
      end
    end

    def snapshot_actor(actor)
      state = ActorState.new
      state.subject_id = actor.subject.object_id
      state.subject_class = actor.subject.class

      tasks = actor.tasks
      if tasks.empty?
        state.status = :idle
      else
        state.status = :running
        state.tasks = tasks.to_a.map { |t| TaskState.new(t.class, t.type, t.meta, t.suspend_meta, t.status, t.backtrace) }
      end

      state.backtrace = actor.thread.backtrace if actor.thread
      state
    end

    def snapshot_thread(thread)
      ThreadState.new(thread.object_id, thread.backtrace)
    end

    def dump(output = STDERR)
      @actors.each do |actor|
        output.print actor.dump
      end

      @threads.each do |thread|
        output.print thread.dump
      end
    end
  end
end
