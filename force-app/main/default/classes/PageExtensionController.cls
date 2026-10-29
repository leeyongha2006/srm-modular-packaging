/**
 * 페이지의 "자리(slot)" 에 그릴 확장 컴포넌트 목록을 돌려준다.
 *
 * Core 는 어떤 모듈이 설치됐는지 모른다. 각 모듈 패키지가 Page_Extension__mdt 에
 * "이 오브젝트의 이 자리에 이 컴포넌트를 그려 달라" 고 등록하면, extensionSlot LWC 가
 * 이 목록을 받아 실행 시점에 컴포넌트를 불러온다. 모듈을 지워도 Core 는 깨지지 않는다.
 */
public with sharing class PageExtensionController {

    private static final String CLASS_NAME = PageExtensionController.class.getName();
    // 패키지로 설치되면 클래스 이름 앞에 네임스페이스가 붙는다 (ns.PageExtensionController).
    private static final String NAMESPACE = CLASS_NAME.contains('.') ? CLASS_NAME.substringBefore('.') : '';

    // Custom Metadata 레코드는 테스트에서 insert 할 수 없어 메모리 레코드를 넣는다.
    @TestVisible
    private static List<Page_Extension__mdt> registryOverride;

    /**
     * @param objectApiName 레코드 페이지 오브젝트 (네임스페이스 유무 상관없음)
     * @param slotName      자리 이름 (예: Tabs)
     * @return SortOrder 순서의 활성 등록 목록, 없으면 빈 목록
     */
    @AuraEnabled(cacheable=true)
    public static List<Extension> getExtensions(String objectApiName, String slotName) {
        try {
            if (String.isBlank(objectApiName) || String.isBlank(slotName)) {
                throw new AuraHandledException('objectApiName and slotName are required.');
            }
            String objectKey = stripNamespace(objectApiName);
            List<Extension> result = new List<Extension>();
            for (Page_Extension__mdt registration : loadRegistry()) {
                if (isMatch(registration, objectKey, slotName)) {
                    result.add(new Extension(registration));
                }
            }
            result.sort();
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[PageExtensionController.getExtensions] ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<Page_Extension__mdt> loadRegistry() {
        return registryOverride != null ? registryOverride : Page_Extension__mdt.getAll().values();
    }

    private static Boolean isMatch(Page_Extension__mdt registration, String objectKey, String slotName) {
        return registration.IsActive__c == true
            && String.isNotBlank(registration.ComponentName__c)
            && objectKey.equalsIgnoreCase(stripNamespace(registration.ObjectApiName__c))
            && slotName.equalsIgnoreCase(registration.Slot__c);
    }

    @TestVisible
    private static String stripNamespace(String apiName) {
        if (String.isBlank(apiName)) {
            return '';
        }
        String prefix = NAMESPACE + '__';
        return String.isNotBlank(NAMESPACE) && apiName.startsWithIgnoreCase(prefix)
            ? apiName.substring(prefix.length())
            : apiName;
    }

    /**
     * 동적 import 에 쓸 모듈 이름. 패키지가 등록한 컴포넌트는 그 패키지의 네임스페이스,
     * 고객 org 에서 직접 등록한 컴포넌트는 c 를 쓴다.
     */
    @TestVisible
    private static String componentModule(Page_Extension__mdt registration) {
        String component = registration.ComponentName__c;
        if (component.contains('/')) {
            return component;
        }
        String namespace = String.isBlank(registration.NamespacePrefix) ? 'c' : registration.NamespacePrefix;
        return namespace + '/' + component;
    }

    public class Extension implements Comparable {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String componentModule;
        @AuraEnabled public String propertiesJson;
        @AuraEnabled public Integer sortOrder;

        public Extension(Page_Extension__mdt registration) {
            this.key = registration.DeveloperName;
            this.label = registration.MasterLabel;
            this.componentModule = PageExtensionController.componentModule(registration);
            this.propertiesJson = registration.PropertiesJson__c;
            this.sortOrder = registration.SortOrder__c == null ? 9999 : registration.SortOrder__c.intValue();
        }

        public Integer compareTo(Object other) {
            Extension that = (Extension) other;
            if (this.sortOrder != that.sortOrder) {
                return this.sortOrder < that.sortOrder ? -1 : 1;
            }
            return this.label.compareTo(that.label);
        }
    }
}
