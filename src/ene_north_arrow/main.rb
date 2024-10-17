module Eneroth
  module EnerothNorthArrow
    # Vary superclass depending on whether this SketchUp version has overlays.
    super_class = defined?(Sketchup::Overlay) ? Sketchup::Overlay : Object

    class NorthArrow < super_class
      # Distance between compass and edge of screen
      MARGIN = 20

      # Radius of compass in logical screen pixels.
      RADIUS = 70

      # Number of segments for circle preview.
      SEGMENTS = 48

      # Points making up approximate circle.
      CIRCLE_POINTS = Array.new(SEGMENTS) do |i|
        angle = Math::PI * 2 / SEGMENTS * i

        [RADIUS * Math.sin(angle), RADIUS * Math.cos(angle)]
      end

      def initialize
        if defined?(Sketchup::Overlay)
          super(PLUGIN_ID, EXTENSION.name, description: EXTENSION.description)
        end
      end

      # Use Both Tool and Overlay API to make the extension work in old SU
      # versions.

      # @api sketchup-observers
      # https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        Sketchup.active_model.active_view.invalidate
      end

      # @api sketchup-observers
      # https://ruby.sketchup.com/Sketchup/Tool.html
      def resume(view)
        view.invalidate
      end

      # @api sketchup-observers
      # @see https://ruby.sketchup.com/Sketchup/Overlay.html
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def draw(view)
        tr = compass_transformation(view)

        view.drawing_color = flip_compass?(view) ? "red" : "black"

        view.draw2d(GL_LINE_LOOP, CIRCLE_POINTS.map { |pt| pt.transform(tr) })
        view.draw2d(GL_LINES, [[-RADIUS, 0, 0], [RADIUS, 0, 0]].map { |pt| pt.transform(tr) })
        view.draw2d(GL_LINES, [[0, -RADIUS, 0], [0, 0, 0]].map { |pt| pt.transform(tr) })
        view.line_width = 3
        view.draw2d(GL_LINES, [[0, RADIUS, 0], [0, 0, 0]].map { |pt| pt.transform(tr) })
      end

      # Get transformation compass internal coordinates to screen space coordinates
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Transformation]
      def compass_transformation(view)
        Geom::Transformation.new(compass_position(view)) *
          Geom::Transformation.rotation(ORIGIN, Z_AXIS, compass_angle(view))
      end

      # Screen space position of compass center.
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Poin3d]
      def compass_position(view)
        # Change here to change the position of the compass on screen.
        bottom_left_corner = Geom::Point3d.new(*view.corner(2), 0)

        bottom_left_corner.offset([RADIUS + MARGIN, -RADIUS - MARGIN, 0])
      end

      # What direction should compass point on screen.
      #
      # Measured counter clockwise from up.
      #
      # @param view [Sketchup::View]
      #
      # @return [Float] Angle in radians.
      def compass_angle(view)
        relative_north = view_angle(view) - north_angle(view)

        if !flip_compass?(view)
          # Looking horizontally or from above.
          180.degrees - relative_north
        else
          relative_north
        end
      end

      # When looking upwards be essentially see the bottom of the compass.
      # It has to point the other way to look right.
      def flip_compass?(view)
        # Somewhat arbitrary number depending on what felt right.
        # REVIEW: Restore 0 as threshold when in parallel projection?
        view.camera.direction.z > 0.3
      end

      # What direction is model north.
      #
      # Measured clockwise from Y axis.
      #
      # @param view [Sketchup::View]
      #
      # @return [Float] Angle in radians.
      def north_angle(view)
        view.model.shadow_info["NorthAngle"].degrees
      end

      # What direction are we looking.
      #
      # Measured clockwise from Y axis.
      #
      # @param view [Sketchup::View]
      #
      # @return [Float] Angle in radians.
      def view_angle(view)
        view_direction = view.camera.direction
        view_direction = view.camera.up if view_direction.parallel?(Z_AXIS)

        angle = planar_angle(Y_AXIS, view_direction)
      end

      # REVIEW: Extract angle_helper.rb?

      # Format angle with correct decimal sign and precision for this model
      # and system.
      #
      # @param angle [Numeric] Angle in radians.
      #
      # @return [String]
      def format_angle(angle)
        positive_angle = angle % (2 * Math::PI)

        # Sketchup.format_angle uses the model's angle precision and the
        # local decimal separator (, or .).
        Sketchup.format_angle(positive_angle)
      end

      # Calculate counter-clockwise angle from vector2 to vector1, as seen from normal.
      #
      # @param vector1 [Geom::Vector3d]
      # @param vector2 [Geom::Vector3d]
      # @param normal [Geom::Vector3d]
      #
      # @return [Numeric] Angle in radians between -pi and pi.
      def planar_angle(vector1, vector2, normal = Z_AXIS)
        Math.atan2((vector2 * vector1) % normal, vector1 % vector2)
      end
    end

    if defined?(Sketchup::Overlay)
      # If SketchUp has Overlays API, use it.
      class OverlayAttacher < Sketchup::AppObserver
        def expectsStartupModelNotifications
          true
        end

        def register_overlay(model)
          overlay = NorthArrow.new
          model.overlays.add(overlay)
        end
        alias_method :onNewModel, :register_overlay
        alias_method :onOpenModel, :register_overlay
      end

      observer = OverlayAttacher.new
      Sketchup.add_observer(observer)

      observer.register_overlay(Sketchup.active_model)
    else
      # For legacy SketchUp, fall back on Tool API and menu item.
      unless @loaded
        @loaded = true

        menu = UI.menu("Plugins")
        menu.add_item(EXTENSION.name) { Sketchup.active_model.select_tool(NorthArrow.new) }
      end
    end
  end
end
