module Eneroth
  module EnerothNorthArrow
    # TODO: Replace with Overlay
    ### unless @loaded
      @loaded = true

      menu = UI.menu("Plugins")
      menu.add_item(EXTENSION.name) { Sketchup.active_model.select_tool(NorthArrow.new) }
    ### end

    class NorthArrow
      # Radius of compass in logical screen pixels.
      RADIUS = 70

      # Number of segments for circle preview.
      SEGMENTS = 48

      # Points making up approximate circle.
      CIRCLE_POINTS = Array.new(SEGMENTS) do |i|
        angle = Math::PI * 2 / SEGMENTS * i

        [RADIUS * Math.sin(angle), RADIUS * Math.cos(angle)]
      end

      def activate
        Sketchup.active_model.active_view.invalidate
      end

      def resume(view)
        view.invalidate
      end

      # @api sketchup-observers
      # @see https://ruby.sketchup.com/Sketchup/AppObserver.html
      def draw(view)
        # Debug stuff. TODO: Remove
        point = [100, 100]
        text = format_angle(view_angle(view))
        view.draw_text(point, text)


        # TODO: Place in lower left corner
        tr = compass_transformation(view)

        view.draw2d(GL_LINE_LOOP, CIRCLE_POINTS.map { |pt| pt.transform(tr) })
        view.draw2d(GL_LINES, [[-RADIUS, 0, 0], [RADIUS, 0, 0]].map { |pt| pt.transform(tr) })
        view.draw2d(GL_LINES, [[0, -RADIUS, 0], [0, 0, 0]].map { |pt| pt.transform(tr) })
        view.line_width = 3
        view.draw2d(GL_LINES, [[0, RADIUS, 0], [0, 0, 0]].map { |pt| pt.transform(tr) })
      end

      # Get transformation compass internal coordinates to screen space coordinates
      #
      # @param view [Sketchup::View]
      # @param position [Geom::Point3d]
      # @param direction [Geom::Vector3d]
      #
      # @return [Geom::Transformation]
      def compass_transformation(view)
        Geom::Transformation.new(Geom::Point3d.new(100, 100, 0)) *
          Geom::Transformation.rotation(ORIGIN, Z_AXIS, compass_angle(view))
      end

      # What direction should compass point on screen.
      #
      # Measured counter clockwise from up.
      #
      # @param view [Sketchup::View]
      #
      # @return [Float] Angle in radians.
      def compass_angle(view)
        if view.camera.direction.z <= 0
          # Looking horizontally or from above.
          180.degrees - view_angle(view)
        else
          # Looking at model from below. Flip compass upside down.
          # REVIEW: Is this what we actually expect when we are ina  building and looking to the ceiling?
          view_angle(view)
        end
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
  end
end
