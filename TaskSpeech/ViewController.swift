//
//  ViewController.swift
//  TaskSpeech
//
//  Created by mac on 6/14/22.
//

import UIKit
import AVFoundation


class ViewController: UIViewController,OEEventsObserverDelegate {

    var slt = Slt()
    var openEarsEventsObserver = OEEventsObserver()
    var fliteController = OEFliteController()

    var usingStartingLanguageModel = Bool()
    var startupFailedDueToLackOfPermissions = Bool()
    var restartAttemptsDueToPermissionRequests = Int()
    var pathToFirstDynamicallyGeneratedLanguageModel: String!
    var pathToFirstDynamicallyGeneratedDictionary: String!
    var pathToSecondDynamicallyGeneratedLanguageModel: String!
    var pathToSecondDynamicallyGeneratedDictionary: String!
    var timer: Timer!






    @IBOutlet weak var AskText: UITextView!
    
   

    
    @IBOutlet weak var startButton: UIButton!
    
    
    @IBOutlet weak var stopButton: UIButton!
  

 
    @IBOutlet weak var sementC: UISegmentedControl!
    
    @IBOutlet weak var heardTextView: UITextView!
   
    
    @IBAction func AskSpeechButton(_ sender: UIButton) {
        var lang: String = "en-US"
        switch sementC.selectedSegmentIndex {
        case 0:
            lang = "en-US"
             break;
        case 1:
            lang = "fr-FR"
             break;
        case 2:
            lang = "de-DE"
             break;
        case 3:
            lang = "es-ES"
             break;

        default:
            lang = "en-US"
            break;
        }

        self.readMe(myText: AskText.text! , myLang: lang)

    }

    func readMe( myText: String , myLang : String) {
        let utterance = AVSpeechUtterance(string: myText )
        utterance.voice = AVSpeechSynthesisVoice(language: myLang)
        utterance.rate = 0.5

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.openEarsEventsObserver.delegate = self
        self.restartAttemptsDueToPermissionRequests = 0
        self.startupFailedDueToLackOfPermissions = false

        let languageModelGenerator = OELanguageModelGenerator()


        let firstLanguageArray = ["one",
                                  "two",
                                  "three",
                                  "four",
                                  "five",
                                  "six",
                                  "seven",
                                  "eight",
                                  "nine"]

        let firstVocabularyName = "FirstVocabulary"

        let firstLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: firstLanguageArray, withFilesNamed: firstVocabularyName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"))

        if(firstLanguageModelGenerationError != nil) {
            print("Error while creating initial language model: \(String(describing: firstLanguageModelGenerationError))")
        } else {
            self.pathToFirstDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: firstVocabularyName)
            self.pathToFirstDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: firstVocabularyName)
            self.usingStartingLanguageModel = true

            let secondVocabularyName = "SecondVocabulary"

            let secondLanguageArray = ["Sunday",
                                       "Monday",
                                       "Tuesday",
                                       "Wednesday",
                                       "Thursday",
                                       "Friday",
                                       "Saturday",
                                       "quidnunc",
                                       "change model"]

            let secondLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: secondLanguageArray, withFilesNamed: secondVocabularyName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"))

            if(secondLanguageModelGenerationError != nil) {
                print("Error while creating second language model: \(String(describing: secondLanguageModelGenerationError))")
            } else {
                self.pathToSecondDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: secondVocabularyName)
                self.pathToSecondDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: secondVocabularyName)
                do {
                    try OEPocketsphinxController.sharedInstance().setActive(true)
                }
                catch {
                    print("Error: it wasn't possible to set the shared instance to active: \"\(error)\"")
                }

               

                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
                }
                
            }
        }
    }

    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) {
        print("Local callback: The received hypothesis is \(hypothesis!) with a score of \(recognitionScore!) and an ID of \(utteranceID!)") // Log it.
        if(hypothesis! == "change model") {

            if(self.usingStartingLanguageModel) {
                OEPocketsphinxController.sharedInstance().changeLanguageModel(toFile: self.pathToSecondDynamicallyGeneratedLanguageModel, withDictionary:self.pathToSecondDynamicallyGeneratedDictionary)
                self.usingStartingLanguageModel = false

            } else {
                OEPocketsphinxController.sharedInstance().changeLanguageModel(toFile: self.pathToFirstDynamicallyGeneratedLanguageModel, withDictionary:self.pathToFirstDynamicallyGeneratedDictionary)
                self.usingStartingLanguageModel = true
            }
        }

        self.heardTextView.text = "Heard: \"\(hypothesis!)\""

        
        self.fliteController.say(_:"You said \(hypothesis!)", with:self.slt)
    }
    
    func audioSessionInterruptionDidEnd() {
        print("Local callback:  AudioSession interruption ended.") // Log it.
       
        
        if(!OEPocketsphinxController.sharedInstance().isListening){
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)

        }
    }

   
    func audioInputDidBecomeUnavailable() {
        print("Local callback:  The audio input has become unavailable")

        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeUnavailable: \(String(describing: stopListeningError))")
            }
        }

      
        func audioInputDidBecomeAvailable() {
            print("Local callback: The audio input is available") // Log it.
          
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            }
        }
        
        func audioRouteDidChange(toRoute newRoute: String!) {
            print("Local callback: Audio route change. The new audio route is \(String(describing: newRoute))") // Log it.
           
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeAvailable: \(String(describing: stopListeningError))")
            }
        }




        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
        }
    }

    


   
    func pocketsphinxDidChangeLanguageModel(toFile newLanguageModelPathAsString: String!, andDictionary newDictionaryPathAsString: String!) {

        print("Local callback: Pocketsphinx is now using the following language model: \n\(newLanguageModelPathAsString!) and the following dictionary: \(newDictionaryPathAsString!)")
    }

   


    func testRecognitionCompleted() {
        print("Local callback: A test file which was submitted for direct recognition via the audio driver is done.")
        if(OEPocketsphinxController.sharedInstance().isListening) {
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in testRecognitionCompleted: \(String(describing: stopListeningError))")
            }
        }

    }
    
    func pocketsphinxFailedNoMicPermissions() {
        print("Local callback: The user has never set mic permissions or denied permission to this app's mic, so listening will not start.")
        self.startupFailedDueToLackOfPermissions = true
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(String(describing: stopListeningError)). Will try again in 10 seconds.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            }
        })
    }


    
    func micPermissionCheckCompleted(withResult: Bool) {
        if(withResult) {

            self.restartAttemptsDueToPermissionRequests += 1
            if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions) {

                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
                }

                self.startupFailedDueToLackOfPermissions = false
            }
        }

    }

   
    @IBAction func StartButtonAction(_ sender: UIButton) {
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) 
        }
       
    }
    

    
       
        
   
    
    @IBAction func stopButtonAction(_ sender: UIButton) {
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(String(describing: stopListeningError))")
            }
        }
      
        
    }
}



