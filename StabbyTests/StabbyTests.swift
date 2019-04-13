//
//  StabbyTests.swift
//  Stabby
//
//  Copyright © 2019 John Kartupelis. All rights reserved.
// 

import XCTest
import Foundation
@testable import Stabby

/**
 *  These things are an over-simplification, and would probably want to move toward
 *  being able to use providers using reflection, as with Dagger. This will probably have
 *  to use reflection combined with a name starting with provides or providesSingleton or something...
 */

class RegisteredDependency {

    let instance: Any
    let type: Any.Type
    let name: String?

    init(instance: Any,
         type: Any.Type,
         name: String?) {
        self.instance = instance
        self.type = type
        self.name = name
    }

    func get() -> Any {
        return instance
    }
}

enum RegistryError: Error {
    case notFound
}

class Registry {

    private var registeredDependencies = [String: [RegisteredDependency]]()

    func registerType<T>(type: T.Type, instance: T, named: String? = nil) {
        let typeString = String(describing: type)
        let registration = RegisteredDependency(instance: instance, type: type, name: named)
        if let existing = registeredDependencies[typeString] {
            var registrations = [registration]
            registrations.append(contentsOf: existing)
            registeredDependencies[typeString] = registrations
        } else {
            let array = [registration]
            registeredDependencies[typeString] = array
        }
    }

    func getType(type: Any.Type, named: String?) throws -> Any {
        let typeString = String(describing: type)
        if let deps = registeredDependencies[typeString] {
            var found: Any?
            deps.forEach { dependency in
                if (dependency.name == named) {
                    found = dependency.get()
                }
            }
            if let nonNullFound = found {
                return nonNullFound
            } else {
                throw RegistryError.notFound
            }
        } else {
            throw RegistryError.notFound
        }
    }
}

class Injector {

    let registry = Registry()

    func registerDependency<T>(type: T.Type,
                               instance: T,
                               named: String? = nil) {
        registry.registerType(type: type, instance: instance, named: named)
    }

    func inject(injectable: Injectable) {
        injectable.getInjectableFields().forEach { field in
            do {
                let dependency = try registry.getType(type: field.injectableType, named: field.named)
                field.inject(dependency)
            } catch {
                fatalError("Dependency not found in injection system \(field.injectableType)")
            }
        }
    }
}


/**
 *  These things are OK as they are.
 */

protocol Injectable {
    func getInjectableFields() -> [InjectableField]
}

extension Injectable {

    func getInjectField<T>(injector: @escaping InjectorFunc<T>,
                           type: T.Type,
                           injectableName: String? = nil) -> InjectableField {
        return InjectorInfo<T>(injectableType: type,
                               named: injectableName,
                               injector: injector)
    }
}

protocol InjectableField {
    var injectableType: Any.Type { get }
    var named: String? { get }
    func inject(_ injectable: Any)
}

typealias InjectorFunc<T> = (T) -> Void

class InjectorInfo<T>: InjectableField {
    var injectableType: Any.Type
    let named: String?
    let injector: InjectorFunc<T>

    init(injectableType: T.Type,
         named: String?,
         injector: @escaping InjectorFunc<T>) {
        self.injectableType = injectableType
        self.named = named
        self.injector = injector
    }

    func inject(_ injectable: Any) {
        if let value = injectable as? T {
            self.injector(value)
        }
    }
}






class StabbyTests: XCTestCase {

    func testExample() {
        // Given

        let inj = Injector()
        inj.registerDependency(type: String.self, instance: "Life, the universe, and everything.")
        inj.registerDependency(type: Int.self, instance: 42)

        let presenter = Presenter()

        // When
        inj.inject(injectable: presenter)

        // Then
        XCTAssertEqual(presenter.injectableField, "Life, the universe, and everything.")
        XCTAssertEqual(presenter.injectableField2, 42)
    }
}

final class Presenter: Injectable {

    var injectableField: String!
    var injectableField2: Int!

    func getInjectableFields() -> [InjectableField] {
        return [
            getInjectField(injector: { value in self.injectableField = value }, type: String.self),
            getInjectField(injector: { value in self.injectableField2 = value }, type: Int.self)
        ]
    }
}
