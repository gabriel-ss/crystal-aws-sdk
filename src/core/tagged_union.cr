module AWS::Core
  module TaggedUnion
    module Member(U, T)
      getter value : T

      def initialize(@value)
      end

      def wrap
        U.new(self)
      end

      forward_missing_to @value
    end

    class UnknownMemberSerializationAttemptException < Exception
      def initialize
        super "Unknown members of unions can't be serialized."
      end
    end

    class UnknownMemberResolveAttemptException < Exception
      def initialize
        super "Attempted to resolve a union member that is not known by the current version of the SDK."
      end
    end

    module UnknownMember
      def initialize
      end

      def self.new(pull : ::JSON::PullParser)
        pull.skip
        new
      end

      def to_json(json : ::JSON::Builder)
        raise UnknownMemberSerializationAttemptException.new
      end
    end
  end
end
