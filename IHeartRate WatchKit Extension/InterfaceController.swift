//
//  InterfaceController.swift
//  IHeartRate WatchKit Extension
//
//  Created by Bryce Schmisseur on 1/23/20.
//  Copyright © 2020 Bryce Schmisseur. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {

    let healthKitStore:HKHealthStore = HKHealthStore();
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    //Function called when the 'Start Recording' button is click within the app
    //This method starts a workout to be able to frequently record the heart rate of the user
    @IBAction func OnStartClick() {
        
        //Creates configuration varibles needed for the workout
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = .walking
        workoutConfig.locationType = .outdoor
        
        // do catch to create the workout
        do {
            session = try HKWorkoutSession(healthStore: healthKitStore, configuration: workoutConfig)
            builder = session!.associatedWorkoutBuilder()
        } catch {
            NSLog("Error Creating WorkoutSession within Do Catch")
            return
        }
        
        //Creates a datasource object to hold the information being recorded
        builder!.dataSource = HKLiveWorkoutDataSource(healthStore: healthKitStore, workoutConfiguration: workoutConfig)

        //Creates Delages to know when new inforamtion is coming in to the objects
        session!.delegate = self
        builder!.delegate = self
        
        //Starts the activity and begins collecting data
        session!.startActivity(with: Date())
        builder!.beginCollection(withStart: Date()) { (success, error) in
            
            guard success else {
                NSLog("Error Starting Workout")
                return
            }
            
            //Confiramtion that the work out has started
            NSLog("Workout Started")
        }
        
    }
    
    //Function called when the 'Stop Recording' button is click within the app
    //This function stops the activity and workout to stop the recording proccess
    @IBAction func OnStopClick() {
        //Ends the workoutSession and the workoutBuilder
        session!.end()
        builder!.endCollection(withEnd: Date(), completion: { (success, error) in
            self.builder!.finishWorkout(completion: { (successIn, errorIn) in
                    
                guard successIn != nil else {
                    NSLog("Error Stoping workout")
                    return
                }
                
                DispatchQueue.main.async {
                    //Confirmation that the workout has stopped
                    NSLog("Stoped Workout")
                }
            })
        })
    }
    
    
    override func awake(withContext context: Any?)
    {
        super.awake(withContext: context)
    }
    
    override func willActivate()
    {
        super.willActivate()
        
        //Create a set for the varibles that are being recorded
        let healthKitRead : Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!];
        
        //Creates a set for the varibles that we are writing too
        let healthKitWrite : Set<HKSampleType> = [];
        
        //Checks to see if there is health data to read
        if !HKHealthStore.isHealthDataAvailable()
        {
            NSLog("Error Occrued: No Health Data");
            return;
        }
        
        //Declares and Instantiate Health to request information from the user
        let healthStore = HKHealthStore()
        healthStore.requestAuthorization(toShare: healthKitWrite, read: healthKitRead) { (success, error) -> Void in
            NSLog("Authorization For Health Kit Accepted")
        }
        
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) -> Void in
            NSLog("Authorization For Workout Kit Accepted")
        }
    }
    
    override func didDeactivate()
    {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        //Declares Varibles
        let heartRateUnit = HKUnit(from: "count/s")
        var heartRate:Int?
        
        //Loops throught the data collected
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }
            
            DispatchQueue.main.async()
            {
                // Calculate statistics for the type.
                let statistics = workoutBuilder.statistics(for: quantityType)
                let recentQuantity = statistics?.mostRecentQuantity()
                
                //Checks to see if the data collected is a heart rate
                if (recentQuantity?.is(compatibleWith: heartRateUnit))!
                {
                    //Converts heart rate from count/s to count/min
                    heartRate = (Int)((recentQuantity?.doubleValue(for: heartRateUnit))! * 60)
                    NSLog("Current Heart Rate is \(heartRate!)")
                    
                    //Sets the url for the rest service call
                    let urlString:String = "http://localhost:8080/IoT-Application/rest/v1/saveHeartRate/\(heartRate!)"
                    let url = URL(string: urlString)
                    
                    //Creates a request obejct with HTTP POST method
                    var request = URLRequest(url: url!)
                    request.httpMethod = "POST"
                    
                    //Pushes the data to the rest services
                    URLSession.shared.getAllTasks { (openTasks: [URLSessionTask]) in
                        NSLog("open tasks: \(openTasks)")
                    }

                    //Infroamtion recived by the rest service
                    let task = URLSession.shared.dataTask(with: request, completionHandler: { (responseData: Data?, response: URLResponse?, error: Error?) in
                        NSLog("\(String(describing: response))")
                    })
                    task.resume()
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }
        
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    }
}
