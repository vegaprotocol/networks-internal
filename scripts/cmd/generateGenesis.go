package cmd

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"time"

	"code.vegaprotocol.io/vega/core/types"
	"github.com/spf13/cobra"
	"github.com/tomwright/dasel"
	"github.com/tomwright/dasel/storage"
	"go.uber.org/zap"
)

type GenerateGenesisArgs struct {
	RootArgs
	ChainIdSuffix      string
	ValidatorIds       []string
	CheckpointFilepath string
}

var generateGenesisArgs GenerateGenesisArgs

var generateGenesisCmd = &cobra.Command{
	Use:   "generate-genesis",
	Short: "Generate genesis for network using template",
	Run: func(cmd *cobra.Command, args []string) {
		generateGenesisArgs.RootArgs = rootArgs
		if err := RunGenerateGenesis(generateGenesisArgs); err != nil {
			rootArgs.Logger.Error("Error", zap.Error(err))
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(generateGenesisCmd)

	generateGenesisCmd.PersistentFlags().StringVar(&generateGenesisArgs.ChainIdSuffix, "chain-id-suffix", "", "Chain Id suffix. If not provided then random value is used")
	generateGenesisCmd.PersistentFlags().StringSliceVar(&generateGenesisArgs.ValidatorIds, "validator-ids", nil, "Comma separated list of Validator ids, e.g. n01,n04,n12")
	if err := generateGenesisCmd.MarkPersistentFlagRequired("validator-ids"); err != nil {
		log.Fatalf("%v\n", err)
	}
	generateGenesisCmd.PersistentFlags().StringVar(&generateGenesisArgs.CheckpointFilepath, "checkpoint", "", "Path to checkpoint. Optional")
}

func RunGenerateGenesis(args GenerateGenesisArgs) error {
	currPath, err := os.Getwd()
	if err != nil {
		return err
	}
	genesisTemplatePath := path.Join(currPath, args.VegaNetworkName, "templates", "genesis-template.json")
	fileWithNodes := path.Join(currPath, args.VegaNetworkName, "templates", "nodes.json")
	generatedGenesisPath := path.Join(currPath, args.VegaNetworkName, "genesis.json")

	//
	// Read template
	//
	if fileInfo, err := os.Stat(genesisTemplatePath); err != nil {
		return fmt.Errorf("failed to read genesis template '%s' file, %w", genesisTemplatePath, err)
	} else if fileInfo.IsDir() {
		return fmt.Errorf("not a file %s", genesisTemplatePath)
	}

	genesis, err := dasel.NewFromFile(genesisTemplatePath, "json")
	if err != nil {
		return err
	}

	nodes, err := readNodesFromFile(fileWithNodes)
	if err != nil {
		return err
	}

	//
	// Modify
	//
	now := time.Now()
	// genesis_time
	genesis_time := now.UTC()
	if err := genesis.Put(".genesis_time", genesis_time); err != nil {
		return fmt.Errorf("failed to set genesis_time, %w", err)
	}
	// genesis_time
	if len(args.ChainIdSuffix) == 0 {
		args.ChainIdSuffix = now.Format("200602011504") // YYYYMMDDHHmm
	}
	chain_id := fmt.Sprintf("vega-%s-%s", args.VegaNetworkName, args.ChainIdSuffix)
	if err := genesis.Put(".chain_id", chain_id); err != nil {
		return fmt.Errorf("failed to set chain_id, %w", err)
	}
	// validators
	if validators, err := getValidatorsSection(nodes, generateGenesisArgs.ValidatorIds); err != nil {
		return fmt.Errorf("failed to generate validators section, %w", err)
	} else {
		if err := genesis.Put(".validators", validators); err != nil {
			return fmt.Errorf("failed to set validators, %w", err)
		}
	}
	// app_state.validators
	if appStateValidators, err := getAppStateValidatorsSection(nodes, generateGenesisArgs.ValidatorIds); err != nil {
		return fmt.Errorf("failed to generate app_state.validators section, %w", err)
	} else {
		if err := genesis.Put(".app_state.validators", appStateValidators); err != nil {
			return fmt.Errorf("failed to set app_state.validators, %w", err)
		}
	}
	// app_state.checkpoint
	if len(args.CheckpointFilepath) > 0 {
		hash, state, err := loadCheckpointFromFile(args.CheckpointFilepath)
		if err != nil {
			return err
		}
		if err := genesis.Put(".app_state.checkpoint", map[string]string{"load_hash": hash, "state": state}); err != nil {
			return fmt.Errorf("failed to set app_state.checkpoint, %w", err)
		}
	}

	//
	// Save generated
	//
	if err := genesis.WriteToFile(generatedGenesisPath, "json", []storage.ReadWriteOption{}); err != nil {
		return fmt.Errorf("failed to save generated genesis, %w", err)
	}

	return nil
}

//
// .validators section
//

type Validators struct {
	Address string `json:"address"`
	Name    string `json:"name"`
	Power   uint64 `json:"power,string"`
	PubKey  struct {
		Type  string `json:"type"`
		Value string `json:"value"`
	} `json:"pub_key"`
}

func getValidatorsSection(nodes map[string]*VegaNodeConfig, validatorIds []string) ([]Validators, error) {
	validators := make([]Validators, len(validatorIds))
	for i, validatorId := range validatorIds {
		if validatorData, ok := nodes[validatorId]; !ok {
			return nil, fmt.Errorf("there is no node %s", validatorId)
		} else {
			validators[i] = Validators{
				Address: validatorData.TendermintValidatorAddress,
				Name:    validatorData.Name,
				Power:   10,
			}
			validators[i].PubKey.Type = "tendermint/PubKeyEd25519"
			validators[i].PubKey.Value = validatorData.TendermintValidatorPubKey
			if len(validators[i].Name) == 0 {
				validators[i].Name = fmt.Sprintf("Validator %s", validatorId)
			}
		}
	}
	return validators, nil
}

//
// .app_state.validators section
//

type AppStateValidators struct {
	AvatarURL        string `json:"avatar_url"`
	Country          string `json:"country"`
	EthereumAddress  string `json:"ethereum_address"`
	Id               string `json:"id"`
	InfoURL          string `json:"info_url"`
	Name             string `json:"name"`
	TendermintPubKey string `json:"tm_pub_key"`
	VegaPubKey       string `json:"vega_pub_key"`
	VegaPubKeyIndex  uint64 `json:"vega_pub_key_index"`
}

func getAppStateValidatorsSection(
	nodes map[string]*VegaNodeConfig,
	validatorIds []string,
) (map[string]AppStateValidators, error) {
	validators := map[string]AppStateValidators{}
	for _, validatorId := range validatorIds {
		if validatorData, ok := nodes[validatorId]; !ok {
			return nil, fmt.Errorf("there is no node %s", validatorId)
		} else {
			validators[validatorData.TendermintValidatorPubKey] = AppStateValidators{
				AvatarURL:        validatorData.AvatarURL,
				Country:          validatorData.Country,
				EthereumAddress:  validatorData.EthereumAddress,
				Id:               validatorData.Id,
				InfoURL:          validatorData.InfoURL,
				Name:             validatorData.Name,
				TendermintPubKey: validatorData.TendermintValidatorPubKey,
				VegaPubKey:       validatorData.VegaPubKey,
				VegaPubKeyIndex:  1,
			}
			// if len(validators[validatorData.TendermintValidatorPubKey].Name) == 0 {
			// 	validators[validatorData.TendermintValidatorPubKey].Name = fmt.Sprintf("Validator %s", validatorId)
			// }
		}
	}
	return validators, nil
}

//
// Read Nodes from local file
//

type VegaNodeConfig struct {
	Node                       string `json:"node"`
	URL                        string `json:"url"`
	EthereumAddress            string `json:"ethereum_address"`
	VegaPubKey                 string `json:"vega_pub_key"`
	Id                         string `json:"id"`
	TendermintNodeId           string `json:"tm_node_id,omitempty"`
	TendermintNodePubKey       string `json:"tm_node_pub_key,omitempty"`
	TendermintValidatorAddress string `json:"tm_validator_address,omitempty"`
	TendermintValidatorPubKey  string `json:"tm_validator_pub_key,omitempty"`
	InfoURL                    string `json:"info_url"`
	Country                    string `json:"country"`
	AvatarURL                  string `json:"avatar_url"`
	Name                       string `json:"name"`
}

func readNodesFromFile(fileWithNodes string) (nodes map[string]*VegaNodeConfig, err error) {
	byteNodes, err := ioutil.ReadFile(fileWithNodes)
	if err != nil {
		return nil, fmt.Errorf("failed to read '%s' file with nodes %w", fileWithNodes, err)
	}
	if err = json.Unmarshal(byteNodes, &nodes); err != nil {
		return nil, fmt.Errorf("failed to parse %s file. %w", fileWithNodes, err)
	}
	return nodes, nil
}

//
// Checkpoint
//

func loadCheckpointFromFile(checkpointFilepath string) (hash string, state string, err error) {
	var (
		buf []byte
	)

	buf, err = ioutil.ReadFile(checkpointFilepath)
	if err != nil {
		err = fmt.Errorf("failed to read checkpoint from file %s, %w", checkpointFilepath, err)
		return
	}

	cpt := &types.CheckpointState{}
	if err = cpt.SetState(buf); err != nil {
		err = fmt.Errorf("invalid restore checkpoint command: %w", err)
		return
	}

	hash = hex.EncodeToString(cpt.Hash)
	state = base64.StdEncoding.EncodeToString(buf)

	return
}
