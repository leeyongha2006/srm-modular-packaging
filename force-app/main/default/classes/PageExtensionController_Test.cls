@IsTest
private class PageExtensionController_Test {

    private static Page_Extension__mdt registration(String name, String objectName, String slot, String component, Integer order, Boolean active) {
        return new Page_Extension__mdt(
            DeveloperName = name,
            MasterLabel = name,
            ObjectApiName__c = objectName,
            Slot__c = slot,
            ComponentName__c = component,
            SortOrder__c = order,
            IsActive__c = active,
            PropertiesJson__c = '{"maxRows":3}'
        );
    }

    @IsTest
    static void returnsActiveRegistrationsForSlotInOrder() {
        PageExtensionController.registryOverride = new List<Page_Extension__mdt>{
            registration('Notes', 'Account', 'Tabs', 'noteExtension', 20, true),
            registration('Contacts', 'Account', 'Tabs', 'contactListExtension', 10, true),
            registration('Inactive', 'Account', 'Tabs', 'oldExtension', 1, false),
            registration('OtherSlot', 'Account', 'Sidebar', 'sideExtension', 1, true),
            registration('OtherObject', 'Opportunity', 'Tabs', 'oppExtension', 1, true),
            registration('NoComponent', 'Account', 'Tabs', null, 1, true)
        };

        List<PageExtensionController.Extension> result = PageExtensionController.getExtensions('account', 'tabs');

        Assert.areEqual(2, result.size());
        Assert.areEqual('Contacts', result[0].key);
        Assert.areEqual('c/contactListExtension', result[0].componentModule);
        Assert.areEqual('{"maxRows":3}', result[0].propertiesJson);
        Assert.areEqual('Notes', result[1].key);
    }

    @IsTest
    static void returnsEmptyListWhenNothingIsRegistered() {
        PageExtensionController.registryOverride = new List<Page_Extension__mdt>();
        Assert.areEqual(0, PageExtensionController.getExtensions('Account', 'Tabs').size());
    }

    @IsTest
    static void keepsExplicitModulePathAndSortsTiesByLabel() {
        Page_Extension__mdt explicit = registration('B', 'Account', 'Tabs', 'acme/partnerCard', 5, true);
        Page_Extension__mdt same = registration('A', 'Account', 'Tabs', 'aCard', 5, true);
        Page_Extension__mdt noOrder = registration('Z', 'Account', 'Tabs', 'zCard', null, true);
        PageExtensionController.registryOverride = new List<Page_Extension__mdt>{ noOrder, explicit, same };

        List<PageExtensionController.Extension> result = PageExtensionController.getExtensions('Account', 'Tabs');

        Assert.areEqual('A', result[0].key);
        Assert.areEqual('acme/partnerCard', result[1].componentModule);
        Assert.areEqual('Z', result[2].key);
    }

    @IsTest
    static void requiresObjectAndSlot() {
        try {
            PageExtensionController.getExtensions('', 'Tabs');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e);
        }
    }

    @IsTest
    static void readsDeployedRegistrations() {
        // 이 저장소가 함께 배포하는 예제 등록 두 건을 실제 Custom Metadata 에서 읽는다.
        List<PageExtensionController.Extension> result = PageExtensionController.getExtensions('Account', 'Tabs');
        Assert.areEqual(2, result.size());
        Assert.areEqual('Contacts_Module', result[0].key);
    }

    @IsTest
    static void stripsOnlyOwnNamespace() {
        Assert.areEqual('Account', PageExtensionController.stripNamespace('Account'));
        Assert.areEqual('', PageExtensionController.stripNamespace(null));
    }
}
