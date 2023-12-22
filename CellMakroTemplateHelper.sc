CellMakroTemplateHelper : CellTemplateHelper {

    init {
         keyLabel = false;
         valueLabel = \spec;
    }

    collectTemplate { |object|
        ^super.collectTemplate(object).asDict;
    }

}
