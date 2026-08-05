public with sharing class LawFirmDashboardController {
    
    // Wrapper para enviar todos los datos juntos
    public class DashboardData {
        @AuraEnabled public Boolean showQuestionnaire;
        @AuraEnabled public String caseStatusDescription;
        @AuraEnabled public String currentPhase;
        @AuraEnabled public String nextStepsDescription;
        @AuraEnabled public List<Map<String, String>> tasks;
        @AuraEnabled public List<Map<String, String>> appointments;
        @AuraEnabled public List<Map<String, String>> legalTeam;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getMatterDetails(Id recordId) {
        DashboardData data = new DashboardData();
        
        data.showQuestionnaire = true; 

        data.caseStatusDescription = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.';

        data.currentPhase = 'Phase 2';

        data.nextStepsDescription = 'Su caso está en fase de revisión. Por favor complete el cuestionario pendiente.';

        data.tasks = new List<Map<String, String>>{
            new Map<String, String>{'id' => '1', 'subject' => 'Subir identificación', 'dueDate' => '2023-10-25', 'isDone' => 'false'},
            new Map<String, String>{'id' => '2', 'subject' => 'Firmar acuerdo', 'dueDate' => '2023-10-28', 'isDone' => 'false'}
        };

        data.appointments = new List<Map<String, String>>{
            new Map<String, String>{'id' => '1', 'subject' => 'Revisión inicial', 'date' => 'Oct 30, 2023'}
        };

        data.legalTeam = new List<Map<String, String>>{
            new Map<String, String>{'name' => 'Eric Parker', 'role' => 'Partner', 'imgUrl' => 'https://www.lightningdesignsystem.com/assets/images/avatar1.jpg'},
            new Map<String, String>{'name' => 'Nancy Keuhl', 'role' => 'Paralegal', 'imgUrl' => 'https://www.lightningdesignsystem.com/assets/images/avatar2.jpg'}
        };

        return data;
    }
}