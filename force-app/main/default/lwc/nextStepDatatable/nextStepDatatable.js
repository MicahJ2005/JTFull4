import LightningDatatable from 'lightning/datatable';
import nameCell from './nameCell.html';

/**
 * Custom datatable for the Next Step task tree.
 * Adds a `taskName` column type that indents by hierarchy level and
 * visually distinguishes Case (structural) rows from Task (leaf) rows.
 * Hours remain a standard editable `number` column on the parent datatable.
 */
export default class NextStepDatatable extends LightningDatatable {
    static customTypes = {
        taskName: {
            template: nameCell,
            standardCellLayout: true,
            typeAttributes: ['level', 'isTask']
        }
    };
}